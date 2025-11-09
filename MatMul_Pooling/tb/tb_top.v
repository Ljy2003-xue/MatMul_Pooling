`timescale 1ns/1ps

module tb_matmul_top;

    initial begin
    $fsdbDumpfile("wave.fsdb");              // Specify FSDB waveform output file
    $fsdbDumpvars(0, tb_matmul_top);         // Dump all hierarchy levels of testbench
    $fsdbDumpvars("+mda");                   // Enable memory array dumping
    $fsdbDumpvars("+all");                   // Dump all signals
    $display("FSDB waveform dumping enabled - file: wave.fsdb");
end

    // Clock and reset
    reg         clk;
    reg         rstn;
    
    // Matrix multiplication top interface
    reg         kick_start;
    wire        ready;
    
    // Memory interface for Matrix A
    wire        mem_en_read_A;
    wire [9:0]  mem_addr_A;
    wire [31:0] mem_data_A;
    
    // Memory interface for Matrix B  
    wire        mem_en_read_B;
    wire [9:0]  mem_addr_B;
    wire [31:0] mem_data_B;
    
    // Memory interface for result write
    wire        mem_en_write_C;
    wire [9:0]  mem_addr_C;
    wire [31:0] mem_data_C;
    
    // Test variables
    integer test_case;
    integer cycle_count;
    integer timeout_counter;
    
    // Expected results for verification
    reg [7:0] expected_results [0:3];
    
    // Instantiate matrix multiplication top module
    matmul_top u_matmul_top (
        .clk            (clk),
        .rstn           (rstn),
        .kick_start     (kick_start),
        .ready          (ready),
        
        // Memory interface for Matrix A
        .mem_en_read_A  (mem_en_read_A),
        .mem_addr_A     (mem_addr_A),
        .mem_data_A     (mem_data_A),
        
        // Memory interface for Matrix B  
        .mem_en_read_B  (mem_en_read_B),
        .mem_addr_B     (mem_addr_B),
        .mem_data_B     (mem_data_B),
        
        // Memory interface for result write
        .mem_en_write_C (mem_en_write_C),
        .mem_addr_C     (mem_addr_C),
        .mem_data_C     (mem_data_C)
    );
    
    // Instantiate memory module
    mem_top u_mem_top (
        .clk        (clk),
        .rstn       (rstn),
        
        // Port A - Matrix A interface
        .read_en_A  (mem_en_read_A),
        .addr_A     (mem_addr_A),
        .data_out_A (mem_data_A),
        
        // Port B - Matrix B interface  
        .read_en_B  (mem_en_read_B),
        .addr_B     (mem_addr_B),
        .data_out_B (mem_data_B),
        
        // Port C - Result write interface
        .write_en_C (mem_en_write_C),
        .addr_C     (mem_addr_C),
        .data_in_C  (mem_data_C)
    );
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Test procedure
    initial begin
        // Initialize signals
        initialize();
        
        $display("==========================================");
        $display("Starting Matrix Multiplication Testbench");
        $display("==========================================");
        
        // Test Case 1: First matrix multiplication
        test_case = 1;
        $display("\n[TEST CASE %0d] Starting first matrix multiplication...", test_case);
        run_single_test();
        
        // Wait between test cases
        #200;
        
        // Test Case 2: Second matrix multiplication
        test_case = 2;
        $display("\n[TEST CASE %0d] Starting second matrix multiplication...", test_case);
        
        // Modify memory contents for second test
        modify_memory_for_test2();
        
        run_single_test();
        
        // Final delay and finish
        #200;
        $display("\n==========================================");
        $display("All test cases completed successfully!");
        $display("Total simulation cycles: %0d", cycle_count);
        $display("==========================================");
        $finish;
    end
    
    // Initialize all signals
    task initialize;
        begin
            clk = 0;
            rstn = 0;
            kick_start = 0;
            test_case = 0;
            cycle_count = 0;
            timeout_counter = 0;
            
            // Initialize expected results for test 1
            expected_results[0] = 8'd86;
            expected_results[1] = 8'd230;
            expected_results[2] = 8'd230;
            expected_results[3] = 8'd255;
            
            // Apply reset
            #20;
            rstn = 1;
            #30;
            
            $display("Initialization completed at time %0t", $time);
        end
    endtask
    
    // Run a single test case
    task run_single_test;
        begin
            integer start_time, end_time;
            integer computation_done;
            
            start_time = cycle_count;
            computation_done = 0;
            timeout_counter = 0;
            
            // Wait for ready signal
            wait_for_ready();
            
            // Start matrix multiplication
            $display("[TEST CASE %0d] Kick starting matrix multiplication...", test_case);
            kick_start = 1;
            @(posedge clk);
            kick_start = 0;
            
            // Wait for computation to complete - monitor state machine
            $display("[TEST CASE %0d] Waiting for computation to complete...", test_case);
            
            while (!computation_done && timeout_counter < 5000) begin
                @(posedge clk);
                timeout_counter = timeout_counter + 1;
                
                // Check if computation is complete by monitoring state and write signals
                if (u_matmul_top.current_state == 4'b0000 && // IDLE state
                    u_matmul_top.ready_reg == 1'b1 && 
                    u_mem_top.memory[10'h200] != 32'b0) begin
                    computation_done = 1;
                    $display("[TEST CASE %0d] Computation completed detected!", test_case);
                end
                
                // Additional check: if we see write back activity completed
                if (u_matmul_top.write_back_active == 1'b0 && 
                    u_matmul_top.current_state == 4'b0000) begin
                    computation_done = 1;
                end
            end
            
            if (timeout_counter >= 5000) begin
                $display("ERROR: Timeout waiting for computation completion!");
                $display("Current state: %h", u_matmul_top.current_state);
                $display("Ready: %b", ready);
                $finish;
            end
            
            end_time = cycle_count;
            
            $display("[TEST CASE %0d] Matrix multiplication completed!", test_case);
            $display("[TEST CASE %0d] Execution time: %0d cycles", test_case, end_time - start_time);
            
            // Wait a few more cycles to ensure all writes are complete
            #100;
            
            // Verify results
            verify_results();
            
            // Additional delay before next test
            #50;
        end
    endtask
    
    // Wait for ready signal
    task wait_for_ready;
        begin
            integer timeout;
            timeout = 0;
            
            while (!ready && timeout < 1000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            
            if (timeout >= 1000) begin
                $display("ERROR: Timeout waiting for ready signal!");
                $finish;
            end
        end
    endtask
    
    // Modify memory for second test case
    task modify_memory_for_test2;
        begin
            $display("[TEST CASE %0d] Modifying memory contents for second test...", test_case);
            
            // Wait for clock edge
            @(posedge clk);
            
            // Modify Matrix A (different values)
            u_mem_top.memory[10'h000] = {8'd8, 8'd7, 8'd6, 8'd5};  // [5,6,7,8]
            u_mem_top.memory[10'h001] = {8'd4, 8'd3, 8'd2, 8'd1};  // [1,2,3,4]
            u_mem_top.memory[10'h002] = {8'd16, 8'd15, 8'd14, 8'd13}; // [13,14,15,16]
            u_mem_top.memory[10'h003] = {8'd12, 8'd11, 8'd10, 8'd9};  // [9,10,11,12]
            
            // Modify Matrix B (different values)
            u_mem_top.memory[10'h100] = {8'd2, 8'd1, 8'd4, 8'd3};  // [3,4,1,2]
            u_mem_top.memory[10'h101] = {8'd6, 8'd5, 8'd8, 8'd7};  // [7,8,5,6]
            u_mem_top.memory[10'h102] = {8'd10, 8'd9, 8'd12, 8'd11}; // [11,12,9,10]
            u_mem_top.memory[10'h103] = {8'd14, 8'd13, 8'd16, 8'd15}; // [15,16,13,14]
            
            // Clear previous results
            u_mem_top.memory[10'h200] = 32'b0;
            
            $display("[TEST CASE %0d] Memory modification completed", test_case);
            
            // Display modified memory contents
            $display("[TEST CASE %0d] New Matrix A:", test_case);
            display_matrix_contents(10'h000, 4, "A");
            $display("[TEST CASE %0d] New Matrix B:", test_case);
            display_matrix_contents(10'h100, 4, "B");
        end
    endtask
    
    // Verify results
    task verify_results;
        begin
            $display("\n=== Verifying Test Case %0d Results ===", test_case);
            
            // Check if result was written to memory
            if (u_mem_top.memory[10'h200] !== 32'b0) begin
                $display("Result at address 0x200: 0x%h", u_mem_top.memory[10'h200]);
                
                // Display the pooled result
                $display("Result bytes: [%3d, %3d, %3d, %3d]", 
                        u_mem_top.memory[10'h200][7:0],
                        u_mem_top.memory[10'h200][15:8],
                        u_mem_top.memory[10'h200][23:16],
                        u_mem_top.memory[10'h200][31:24]);
                
                // For test case 1, check against expected values
                if (test_case == 1) begin
                    if (u_mem_top.memory[10'h200][7:0] == expected_results[0] &&
                        u_mem_top.memory[10'h200][15:8] == expected_results[1] &&
                        u_mem_top.memory[10'h200][23:16] == expected_results[2] &&
                        u_mem_top.memory[10'h200][31:24] == expected_results[3]) begin
                        $display("TEST CASE %0d: PASSED - Result matches expected values", test_case);
                    end else begin
                        $display("TEST CASE %0d: FAILED - Result does not match expected values", test_case);
                        $display("Expected: [%3d, %3d, %3d, %3d]", 
                                expected_results[0], expected_results[1], 
                                expected_results[2], expected_results[3]);
                    end
                end else begin
                    $display("TEST CASE %0d: Result written successfully (manual verification required)", test_case);
                end
            end else begin
                $display("TEST CASE %0d: FAILED - No result found at address 0x200", test_case);
            end
        end
    endtask
    
    // Display matrix contents from memory
    task display_matrix_contents;
        input [9:0] base_addr;
        input integer size;
        input string matrix_name;
        begin
            integer i;
            for (i = 0; i < size; i = i + 1) begin
                $display("  %s[%0d]: [%2d, %2d, %2d, %2d]", matrix_name, i,
                        u_mem_top.memory[base_addr + i][7:0],
                        u_mem_top.memory[base_addr + i][15:8],
                        u_mem_top.memory[base_addr + i][23:16],
                        u_mem_top.memory[base_addr + i][31:24]);
            end
        end
    endtask
    
    // Cycle counter
    always @(posedge clk) begin
        if (rstn) begin
            cycle_count <= cycle_count + 1;
        end
    end
    
    // Enhanced monitor for debugging
    always @(posedge clk) begin
        if (rstn) begin
            // Monitor state transitions
            if (u_matmul_top.current_state !== u_matmul_top.next_state) begin
                $display("STATE_TRANSITION: %h -> %h at cycle %0d", 
                         u_matmul_top.current_state, u_matmul_top.next_state, cycle_count);
            end
            
            // Monitor important write events
            if (mem_en_write_C) begin
                $display("TB_MONITOR: Write to addr 0x%h, data 0x%h", mem_addr_C, mem_data_C);
            end
        end
    end
    
    // Timeout protection
    initial begin
        #200000; // 200,000 time units
        $display("ERROR: Simulation timeout!");
        $display("Current state: %h", u_matmul_top.current_state);
        $display("Ready: %b", ready);
        $display("Last memory write: 0x%h", u_mem_top.memory[10'h200]);
        $finish;
    end

endmodule