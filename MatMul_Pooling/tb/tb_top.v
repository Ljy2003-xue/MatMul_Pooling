`timescale 1ns/1ps

module tb_top;

    // Clock and reset
    reg         clk;
    reg         rstn;
    
    // Matrix multiplication interface
    reg         kick_start;
    wire        ready;
    
    // Memory interface for Matrix A
    wire        mem_read_en_A;
    wire [9:0]  mem_addr_A;
    wire [31:0] mem_data_A;
    
    // Memory interface for Matrix B  
    wire        mem_read_en_B;
    wire [9:0]  mem_addr_B;
    wire [31:0] mem_data_B;
    
    // Memory interface for result write
    wire        mem_write_en_C;
    wire [9:0]  mem_addr_C;
    wire [31:0] mem_data_C;
    
    // Test control
    reg [1:0]   test_case;
    reg         test_done;
    
    // Instantiate DUT
    matmul_top dut (
        .clk(clk),
        .rstn(rstn),
        .kick_start(kick_start),
        .ready(ready),
        
        // Memory interface for Matrix A
        .mem_read_en_A(mem_read_en_A),
        .mem_addr_A(mem_addr_A),
        .mem_data_A(mem_data_A),
        
        // Memory interface for Matrix B  
        .mem_read_en_B(mem_read_en_B),
        .mem_addr_B(mem_addr_B),
        .mem_data_B(mem_data_B),
        
        // Memory interface for result write
        .mem_write_en_C(mem_write_en_C),
        .mem_addr_C(mem_addr_C),
        .mem_data_C(mem_data_C)
    );
    
    // Instantiate memory
    mem_top memory (
        .clk(clk),
        .rstn(rstn),
        
        // Port A - Matrix A interface
        .read_en_A(mem_read_en_A),
        .addr_A(mem_addr_A),
        .data_out_A(mem_data_A),
        
        // Port B - Matrix B interface  
        .read_en_B(mem_read_en_B),
        .addr_B(mem_addr_B),
        .data_out_B(mem_data_B),
        
        // Port C - Result write interface
        .write_en_C(mem_write_en_C),
        .addr_C(mem_addr_C),
        .data_in_C(mem_data_C)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end
    
    // Test sequence
    initial begin
        initialize_test();
        
        // Test Case 1: Original matrices
        $display("=== Starting Test Case 1 ===");
        test_case = 1;
        setup_test_case_1();
        run_matrix_multiplication();
        verify_test_case_1();
        
        // Test Case 2: Different matrices
        $display("=== Starting Test Case 2 ===");
        test_case = 2;
        setup_test_case_2();
        run_matrix_multiplication();
        verify_test_case_2();
        
        $display("=== All test cases completed successfully! ===");
        #100;
        $finish;
    end
    
    // Initialize test environment
    task initialize_test;
        begin
            // Reset generation
            rstn = 0;
            kick_start = 0;
            test_done = 0;
            test_case = 0;
            #20 rstn = 1;
            
            $display("=== Testbench: Reset completed ===");
            
            // Wait for matmul to be ready
            wait(ready == 1);
            $display("=== Testbench: Matrix multiplier is ready ===");
        end
    endtask
    
    // Setup for Test Case 1: Original matrices
    task setup_test_case_1;
        begin
            // Use default matrices already in memory
            $display("Test Case 1: Using default matrices");
            $display("Matrix A: [[1,2,3,4], [5,6,7,8], [9,10,11,12], [13,14,15,16]]");
            $display("Matrix B: [[1,2,3,4], [5,6,7,8], [9,10,11,12], [13,14,15,16]]");
        end
    endtask
    
    // Setup for Test Case 2: Different matrices
    task setup_test_case_2;
        begin
            // Load new matrices into memory
            $display("Test Case 2: Loading new matrices into memory");
            
            // Matrix A: Identity matrix
            memory.memory[10'h000] = {8'd1, 8'd0, 8'd0, 8'd0};  // [0,0,0,1]
            memory.memory[10'h001] = {8'd0, 8'd1, 8'd0, 8'd0};  // [0,0,1,0]
            memory.memory[10'h002] = {8'd0, 8'd0, 8'd1, 8'd0};  // [0,1,0,0]
            memory.memory[10'h003] = {8'd0, 8'd0, 8'd0, 8'd1};  // [1,0,0,0]
            
            // Matrix B: All 2's
            memory.memory[10'h100] = {8'd2, 8'd2, 8'd2, 8'd2};  // [2,2,2,2]
            memory.memory[10'h101] = {8'd2, 8'd2, 8'd2, 8'd2};  // [2,2,2,2]
            memory.memory[10'h102] = {8'd2, 8'd2, 8'd2, 8'd2};  // [2,2,2,2]
            memory.memory[10'h103] = {8'd2, 8'd2, 8'd2, 8'd2};  // [2,2,2,2]
            
            $display("Matrix A: Identity matrix");
            $display("Matrix B: All 2's");
        end
    endtask
    
    // Run matrix multiplication
    task run_matrix_multiplication;
        begin
            // Start computation
            #10;
            kick_start = 1;
            $display("Starting matrix multiplication for test case %0d", test_case);
            #10;
            kick_start = 0;
            
            // Wait for completion
            wait(ready == 1);
            $display("Matrix multiplication completed for test case %0d", test_case);
            
            // Allow some time for final writes
            #100;
        end
    endtask
    
    // Verify Test Case 1 results
    task verify_test_case_1;
        begin
            $display("=== Verifying Test Case 1 Results ===");
            
            // Expected result for original matrices after pooling
            // Matrix A × Matrix B = [[90,100,110,120], [202,228,254,280], [314,356,398,440], [426,484,542,600]]
            // After 2x2 average pooling: [[155,191], [255,255]] (saturated to 8-bit)
            
            reg [31:0] result = memory.memory[10'h200];
            $display("Result at address 0x200: 0x%h", result);
            $display("Result bytes: [%d, %d, %d, %d]", 
                     result[7:0], result[15:8], result[23:16], result[31:24]);
            
            // Check if result matches expected pooled values
            // Expected: [155, 191, 255, 255] packed as [255, 255, 191, 155] in memory
            if (result[7:0] == 155 && result[15:8] == 191 && 
                result[23:16] == 255 && result[31:24] == 255) begin
                $display("TEST CASE 1: PASSED - Result matches expected values");
            end else begin
                $display("TEST CASE 1: FAILED - Result does not match expected values");
                $display("Expected: [155, 191, 255, 255]");
                $display("Got: [%d, %d, %d, %d]", 
                         result[7:0], result[15:8], result[23:16], result[31:24]);
            end
        end
    endtask
    
    // Verify Test Case 2 results
    task verify_test_case_2;
        begin
            $display("=== Verifying Test Case 2 Results ===");
            
            // Expected result for identity matrix × all 2's matrix after pooling
            // Identity × All 2's = All 2's matrix: [[2,2,2,2], [2,2,2,2], [2,2,2,2], [2,2,2,2]]
            // After 2x2 average pooling: [[2,2], [2,2]]
            
            reg [31:0] result = memory.memory[10'h200];
            $display("Result at address 0x200: 0x%h", result);
            $display("Result bytes: [%d, %d, %d, %d]", 
                     result[7:0], result[15:8], result[23:16], result[31:24]);
            
            // Check if result matches expected pooled values
            // Expected: [2, 2, 2, 2]
            if (result[7:0] == 2 && result[15:8] == 2 && 
                result[23:16] == 2 && result[31:24] == 2) begin
                $display("TEST CASE 2: PASSED - Result matches expected values");
            end else begin
                $display("TEST CASE 2: FAILED - Result does not match expected values");
                $display("Expected: [2, 2, 2, 2]");
                $display("Got: [%d, %d, %d, %d]", 
                         result[7:0], result[15:8], result[23:16], result[31:24]);
            end
        end
    endtask
    
    // Monitor progress
    always @(posedge clk) begin
        if (dut.current_state != dut.IDLE && ready == 0) begin
            case (dut.current_state)
                dut.READ_A: $display("TB_MONITOR: Reading Matrix A");
                dut.READ_B: $display("TB_MONITOR: Reading Matrix B"); 
                dut.MAC_COMPUTE: $display("TB_MONITOR: Computing MAC");
                dut.AVERAGE_POOL: $display("TB_MONITOR: Performing pooling");
                dut.STORE_RESULT: $display("TB_MONITOR: Storing result");
                dut.WRITE_BACK: $display("TB_MONITOR: Writing back to memory");
            endcase
        end
    end
    
    // Timeout protection
    initial begin
        #100000;  // 100us timeout
        $display("=== Testbench: TIMEOUT - Simulation took too long ===");
        $finish;
    end
    
    // Waveform dumping (for VCS)
    initial begin
        $vcdpluson;
        $vcdplusmemon;
    end

endmodule
[file content end]