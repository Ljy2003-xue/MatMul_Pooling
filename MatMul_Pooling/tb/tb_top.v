module tb_top;

    // Clock and reset
    reg clk;
    reg rstn;
    
    // MatMul interface
    reg kick_start;
    wire ready;
    
    // Memory interfaces - 扩展为10位地址
    wire mem_read_en_A;
    wire [9:0] mem_addr_A;
    wire [31:0] mem_data_A;
    
    wire mem_read_en_B;
    wire [9:0] mem_addr_B;
    wire [31:0] mem_data_B;
    
    wire mem_write_en_C;
    wire [9:0] mem_addr_C;
    wire [31:0] mem_data_C;

    // Test control
    integer test_count;
    integer pass_count;

    // Instantiate matmul_top with pooling ENABLED
    matmul_top #(.ENABLE_POOLING(1)) u_matmul (
        .clk(clk),
        .rstn(rstn),
        .kick_start(kick_start),
        .ready(ready),
        .mem_read_en_A(mem_read_en_A),
        .mem_addr_A(mem_addr_A),
        .mem_data_A(mem_data_A),
        .mem_read_en_B(mem_read_en_B),
        .mem_addr_B(mem_addr_B),
        .mem_data_B(mem_data_B),
        .mem_write_en_C(mem_write_en_C),
        .mem_addr_C(mem_addr_C),
        .mem_data_C(mem_data_C)
    );

    // Instantiate mem_top
    mem_top u_memory (
        .clk(clk),
        .rstn(rstn),
        .read_en_A(mem_read_en_A),
        .addr_A(mem_addr_A),
        .data_out_A(mem_data_A),
        .read_en_B(mem_read_en_B),
        .addr_B(mem_addr_B),
        .data_out_B(mem_data_B),
        .write_en_C(mem_write_en_C),
        .addr_C(mem_addr_C),
        .data_in_C(mem_data_C)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Main test sequence
    initial begin
        // Initialize test control
        test_count = 0;
        pass_count = 0;
        
        // Initialize signals
        rstn = 0;
        kick_start = 0;
        
        $display("==========================================");
        $display("Starting Multiple Matrix Multiplication Tests");
        $display("==========================================");
        
        // Apply reset
        #100;
        rstn = 1;
        #100;
        
        // Test 1: Original test case
        run_test("Test 1 - Original Matrices", 1);
        
        // Test 2: Identity matrix multiplication
        run_test("Test 2 - Identity Matrices", 2);
        
        // Test 3: Zero matrix multiplication  
        run_test("Test 3 - Zero Matrices", 3);
        
        // Test 4: Random matrix multiplication
        run_test("Test 4 - Random Matrices", 4);
        
        // Test 5: Edge case - large values
        run_test("Test 5 - Large Values", 5);
        
        // Summary
        $display("==========================================");
        $display("TEST SUMMARY: %0d/%0d tests passed", pass_count, test_count);
        $display("==========================================");
        
        #100;
        $finish;
    end

    // Task to run individual test
    task run_test;
        input [80:0] test_name;
        input integer test_num;
        begin
            test_count = test_count + 1;
            $display("\n==========================================");
            $display("Running %s at time %0t", test_name, $time);
            $display("==========================================");
            
            // Initialize memory for this test
            initialize_memory(test_num);
            
            // Wait for ready
            wait(ready == 1);
            #20;
            
            // Start operation
            kick_start = 1;
            #20;
            kick_start = 0;
            
            // Wait for completion with timeout
            fork
                begin
                    wait(ready == 1);
                    $display("%s completed at time %0t", test_name, $time);
                    
                    // Verify results
                    if (verify_results(test_num)) begin
                        pass_count = pass_count + 1;
                        $display("%s: PASSED", test_name);
                    end else begin
                        $display("%s: FAILED", test_name);
                    end
                end
                begin
                    #10000; // 10us timeout
                    $display("ERROR: %s timeout at time %0t!", test_name, $time);
                    $display("Current state: %h", u_matmul.current_state);
                end
            join_any
            
            // Disable timeout
            disable fork;
            
            // Reset for next test
            #100;
            rstn = 0;
            #50;
            rstn = 1;
            #100;
        end
    endtask

    // Task to initialize memory based on test case
    task initialize_memory;
        input integer test_case;
        integer i, j;
        reg [7:0] temp_A [0:3][0:3];
        reg [7:0] temp_B [0:3][0:3];
        begin
            // Clear memory first
            for (i = 0; i < 1024; i = i + 1) begin
                u_memory.memory[i] = 32'b0;
            end
            
            case (test_case)
                1: begin // Original test case
                    // Matrix A (row major)
                    temp_A[0][0] = 1; temp_A[0][1] = 2; temp_A[0][2] = 3; temp_A[0][3] = 4;
                    temp_A[1][0] = 5; temp_A[1][1] = 6; temp_A[1][2] = 7; temp_A[1][3] = 8;
                    temp_A[2][0] = 9; temp_A[2][1] = 10; temp_A[2][2] = 11; temp_A[2][3] = 12;
                    temp_A[3][0] = 13; temp_A[3][1] = 14; temp_A[3][2] = 15; temp_A[3][3] = 16;
                    
                    // Matrix B (column major)
                    temp_B[0][0] = 1; temp_B[1][0] = 2; temp_B[2][0] = 3; temp_B[3][0] = 4;
                    temp_B[0][1] = 5; temp_B[1][1] = 6; temp_B[2][1] = 7; temp_B[3][1] = 8;
                    temp_B[0][2] = 9; temp_B[1][2] = 10; temp_B[2][2] = 11; temp_B[3][2] = 12;
                    temp_B[0][3] = 13; temp_B[1][3] = 14; temp_B[2][3] = 15; temp_B[3][3] = 16;
                end
                
                2: begin // Identity matrices
                    // Matrix A = Identity (row major)
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            temp_A[i][j] = (i == j) ? 8'd1 : 8'd0;
                        end
                    end
                    
                    // Matrix B = Identity (column major)
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            temp_B[i][j] = (i == j) ? 8'd1 : 8'd0;
                        end
                    end
                end
                
                3: begin // Zero matrices
                    // Matrix A = Zero (row major)
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            temp_A[i][j] = 8'd0;
                        end
                    end
                    
                    // Matrix B = Zero (column major)
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            temp_B[i][j] = 8'd0;
                        end
                    end
                end
                
                4: begin // Random matrices
                    // Generate random values for Matrix A (row major)
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            temp_A[i][j] = {$random} % 16; // Values 0-15
                        end
                    end
                    
                    // Generate random values for Matrix B (column major)
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            temp_B[i][j] = {$random} % 16; // Values 0-15
                        end
                    end
                    
                    $display("Random Matrix A:");
                    for (i = 0; i < 4; i = i + 1) begin
                        $display("  Row %0d: %2d %2d %2d %2d", i, 
                                temp_A[i][0], temp_A[i][1], temp_A[i][2], temp_A[i][3]);
                    end
                    $display("Random Matrix B:");
                    for (i = 0; i < 4; i = i + 1) begin
                        $display("  Col %0d: %2d %2d %2d %2d", i, 
                                temp_B[0][i], temp_B[1][i], temp_B[2][i], temp_B[3][i]);
                    end
                end
                
                5: begin // Large values (near saturation)
                    // Matrix A with large values (row major)
                    temp_A[0][0] = 200; temp_A[0][1] = 180; temp_A[0][2] = 160; temp_A[0][3] = 140;
                    temp_A[1][0] = 120; temp_A[1][1] = 100; temp_A[1][2] = 80; temp_A[1][3] = 60;
                    temp_A[2][0] = 40; temp_A[2][1] = 30; temp_A[2][2] = 20; temp_A[2][3] = 10;
                    temp_A[3][0] = 5; temp_A[3][1] = 10; temp_A[3][2] = 15; temp_A[3][3] = 20;
                    
                    // Matrix B with large values (column major)
                    temp_B[0][0] = 50; temp_B[1][0] = 45; temp_B[2][0] = 40; temp_B[3][0] = 35;
                    temp_B[0][1] = 30; temp_B[1][1] = 25; temp_B[2][1] = 20; temp_B[3][1] = 15;
                    temp_B[0][2] = 10; temp_B[1][2] = 8; temp_B[2][2] = 6; temp_B[3][2] = 4;
                    temp_B[0][3] = 2; temp_B[1][3] = 4; temp_B[2][3] = 6; temp_B[3][3] = 8;
                end
            endcase
            
            // Write Matrix A to memory (row major) - 使用10位地址
            for (i = 0; i < 4; i = i + 1) begin
                u_memory.memory[i] = {temp_A[i][3], temp_A[i][2], temp_A[i][1], temp_A[i][0]};
            end
            
            // Write Matrix B to memory (column major) - 使用10位地址
            for (i = 0; i < 4; i = i + 1) begin
                u_memory.memory[10'h100 + i] = {temp_B[3][i], temp_B[2][i], temp_B[1][i], temp_B[0][i]};
            end
            
            $display("Memory initialized for test case %0d", test_case);
        end
    endtask

    // Task to verify results based on test case - 修改为验证池化结果
    function automatic integer verify_results;
        input integer test_case;
        integer errors;
        reg [31:0] expected [0:3];
        reg [31:0] calculated [0:3];
        integer i, j, k;
        reg [15:0] dot_product;
        reg [7:0] temp_A [0:3][0:3];
        reg [7:0] temp_B [0:3][0:3];
        reg [7:0] temp_C [0:3][0:3];
        reg [7:0] temp_P [0:1][0:1];  // 池化结果
        begin
            errors = 0;
            
            case (test_case)
                1: begin // Original test case - 计算池化后的预期值
                    // 先计算矩阵乘法结果
                    temp_C[0][0] = 30;  temp_C[0][1] = 70;  temp_C[0][2] = 110; temp_C[0][3] = 150;
                    temp_C[1][0] = 70;  temp_C[1][1] = 174; temp_C[1][2] = 278; temp_C[1][3] = 382;
                    temp_C[2][0] = 110; temp_C[2][1] = 278; temp_C[2][2] = 446; temp_C[2][3] = 614;
                    temp_C[3][0] = 150; temp_C[3][1] = 382; temp_C[3][2] = 614; temp_C[3][3] = 846;
                    
                    // 应用饱和处理
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            if (temp_C[i][j] > 255) temp_C[i][j] = 255;
                        end
                    end
                    
                    // 计算2x2平均池化
                    temp_P[0][0] = (temp_C[0][0] + temp_C[0][1] + temp_C[1][0] + temp_C[1][1]) >> 2;  // (30+70+70+174)/4 = 86
                    temp_P[0][1] = (temp_C[0][2] + temp_C[0][3] + temp_C[1][2] + temp_C[1][3]) >> 2;  // (110+150+255+255)/4 = 192
                    temp_P[1][0] = (temp_C[2][0] + temp_C[2][1] + temp_C[3][0] + temp_C[3][1]) >> 2;  // (110+255+150+255)/4 = 192
                    temp_P[1][1] = (temp_C[2][2] + temp_C[2][3] + temp_C[3][2] + temp_C[3][3]) >> 2;  // (255+255+255+255)/4 = 255
                    
                    expected[0] = {temp_P[0][1], temp_P[0][0], temp_P[0][1], temp_P[0][0]};  // P[0][1], P[0][0]
                    expected[1] = {temp_P[1][1], temp_P[1][0], temp_P[0][1], temp_P[0][0]};  // P[1][1], P[1][0]
                end
                
                2: begin // Identity matrices - 池化后的结果
                    // 单位矩阵相乘还是单位矩阵，池化后每个2x2区域平均值
                    temp_P[0][0] = (1+0+0+0) >> 2;  // 0
                    temp_P[0][1] = (0+1+0+0) >> 2;  // 0
                    temp_P[1][0] = (0+0+1+0) >> 2;  // 0
                    temp_P[1][1] = (0+0+0+1) >> 2;  // 0
                    
                    expected[0] = {temp_P[0][1], temp_P[0][0], temp_P[0][1], temp_P[0][0]};
                    expected[1] = {temp_P[1][1], temp_P[1][0], temp_P[0][1], temp_P[0][0]};
                end
                
                3: begin // Zero matrices - 池化后还是零
                    temp_P[0][0] = 0;
                    temp_P[0][1] = 0;
                    temp_P[1][0] = 0;
                    temp_P[1][1] = 0;
                    
                    expected[0] = {temp_P[0][1], temp_P[0][0], temp_P[0][1], temp_P[0][0]};
                    expected[1] = {temp_P[1][1], temp_P[1][0], temp_P[0][1], temp_P[0][0]};
                end
                
                4, 5: begin // Random and large values - 计算预期池化结果
                    // Read back matrices from memory to calculate expected result
                    for (i = 0; i < 4; i = i + 1) begin
                        {temp_A[i][3], temp_A[i][2], temp_A[i][1], temp_A[i][0]} = u_memory.memory[i];
                    end
                    for (i = 0; i < 4; i = i + 1) begin
                        {temp_B[3][i], temp_B[2][i], temp_B[1][i], temp_B[0][i]} = u_memory.memory[10'h100 + i];
                    end
                    
                    // Calculate expected result C = A * B with saturation
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            dot_product = 0;
                            for (k = 0; k < 4; k = k + 1) begin
                                dot_product = dot_product + (temp_A[i][k] * temp_B[k][j]);
                            end
                            // 应用饱和处理：如果超过255则取255
                            temp_C[i][j] = (dot_product > 255) ? 8'd255 : dot_product[7:0];
                        end
                    end
                    
                    // 计算2x2平均池化
                    temp_P[0][0] = (temp_C[0][0] + temp_C[0][1] + temp_C[1][0] + temp_C[1][1]) >> 2;
                    temp_P[0][1] = (temp_C[0][2] + temp_C[0][3] + temp_C[1][2] + temp_C[1][3]) >> 2;
                    temp_P[1][0] = (temp_C[2][0] + temp_C[2][1] + temp_C[3][0] + temp_C[3][1]) >> 2;
                    temp_P[1][1] = (temp_C[2][2] + temp_C[2][3] + temp_C[3][2] + temp_C[3][3]) >> 2;
                    
                    // Format expected results
                    expected[0] = {temp_P[0][1], temp_P[0][0], temp_P[0][1], temp_P[0][0]};
                    expected[1] = {temp_P[1][1], temp_P[1][0], temp_P[0][1], temp_P[0][0]};
                end
            endcase
            
            // Read actual results from memory - 使用10位地址
            calculated[0] = u_memory.memory[10'h200];
            calculated[1] = u_memory.memory[10'h201];
            
            // Display results
            $display("Expected vs Actual POOLED results:");
            $display("Address 0x200 - Exp: P[0]=%3d, P[1]=%3d, Act: P[0]=%3d, P[1]=%3d",
                    expected[0][7:0], expected[0][15:8],
                    calculated[0][7:0], calculated[0][15:8]);
            $display("Address 0x201 - Exp: P[2]=%3d, P[3]=%3d, Act: P[2]=%3d, P[3]=%3d",
                    expected[1][7:0], expected[1][15:8],
                    calculated[1][7:0], calculated[1][15:8]);
            
            // Check results - 只检查前两个地址，因为池化结果只有2x2=4个元素，存储在2个地址中
            for (i = 0; i < 2; i = i + 1) begin
                if (calculated[i] !== expected[i]) begin
                    $display("ERROR: Address 0x%h mismatch! Got %h, Expected %h", 
                            10'h200 + i, calculated[i], expected[i]);
                    errors = errors + 1;
                end
            end
            
            if (errors == 0) begin
                $display("SUCCESS: All pooled results match expected values!");
                verify_results = 1;
            end else begin
                $display("FAILED: %0d errors found in pooled results!", errors);
                verify_results = 0;
            end
        end
    endfunction

    // VCD dump for waveform analysis
    initial begin
        $dumpfile("matmul_multi_test.vcd");
        $dumpvars(0, tb_top);
    end

endmodule