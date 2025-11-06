module matmul_top (
    input  wire        clk,
    input  wire        rstn,
    input  wire        kick_start,
    output wire        ready,
    
    // Memory interface for Matrix A
    output wire        mem_read_en_A,
    output wire [9:0]  mem_addr_A,  
    input  wire [31:0] mem_data_A,
    
    // Memory interface for Matrix B  
    output wire        mem_read_en_B,
    output wire [9:0]  mem_addr_B,  
    input  wire [31:0] mem_data_B,
    
    // Memory interface for result write
    output wire        mem_write_en_C,
    output wire [9:0]  mem_addr_C,  
    output wire [31:0] mem_data_C
);

   
    // State definitions - Enhanced FSM
    parameter [3:0] IDLE         = 4'b0000;
    parameter [3:0] READ_A       = 4'b0001;
    parameter [3:0] READ_B       = 4'b0010;
    parameter [3:0] MAC_COMPUTE  = 4'b0011;
    parameter [3:0] AVERAGE_POOL = 4'b0100;
    parameter [3:0] STORE_RESULT = 4'b0101;
    parameter [3:0] WRITE_BACK   = 4'b0110;
    parameter [3:0] RESET        = 4'b0111;

    // Internal registers
    reg [3:0]  current_state, next_state;//state register
    reg [1:0]  row_cnt, col_cnt, inner_cnt,readA_cnt,readB_cnt;//counter
    
    reg [15:0] mac_accumulator;
    
    reg [7:0]  result_buffer [0:3][0:3];

    reg [1:0]  pool_row_cnt, pool_col_cnt;
    reg [7:0]  pooled_buffer [0:1][0:1];
    
    reg [7:0]  a_row_buffer [0:3];
    reg [7:0]  b_col_buffer [0:3];

    
    reg        ready_reg;
    reg        write_back_active;   
    
    // Read completion signals
    reg        readA_done;
    reg        readB_done;
    reg        matmul_done;
    
    
    // Control signals 
    reg [9:0]  base_addr_A, base_addr_B, base_addr_C;
    
    // Status flags
    wire       fetch_done;
    wire       pool_done;
  
    
    // Integer for loops
    integer i, j;
    
    // Status assignments
    
    assign pool_done  = (pool_row_cnt == 1'b1 && pool_col_cnt == 1'b1);
   
    
    // Output assignments
    assign ready = ready_reg;
    assign mem_read_en_A = (current_state == READ_A);
    assign mem_read_en_B = (current_state == READ_B);
    assign mem_write_en_C = write_back_active;
    
    // Address generation - 使用10位地址
    assign mem_addr_A = base_addr_A + {7'b0, row_cnt};           // A矩阵：0x00-0x03
    assign mem_addr_B = base_addr_B + {7'b0, col_cnt};           // B矩阵：0x100-0x103  
    assign mem_addr_C = base_addr_C ;                            // C矩阵：0x200
    
    // Result data output 
    assign mem_data_C = {pooled_buffer[1][1], pooled_buffer[1][0], 
                     pooled_buffer[0][1], pooled_buffer[0][0]};

    // State machine
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic - Serial read mode
    always @(*) begin
        case (current_state)
            IDLE: begin
                next_state = (kick_start && ready) ? READ_A : IDLE;
            end
            READ_A: begin
                next_state = readA_done ? READ_B : READ_A;
            end
            READ_B: begin
                next_state = readB_done ? MAC_COMPUTE : READ_B;
            end
            MAC_COMPUTE: begin
                
                next_state = matmul_done ? AVERAGE_POOL : READ_A;
            end
            AVERAGE_POOL: begin
                next_state = pool_done ? WRITE_BACK : AVERAGE_POOL;
            end
            WRITE_BACK: begin
                next_state = IDLE;  // 直接回到IDLE
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Control signals and counters
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // Reset all registers
            current_state <= IDLE;
            ready_reg     <= 1'b1;

            row_cnt   <= 2'b0;
            col_cnt   <= 2'b0;
            inner_cnt <= 2'b0;
            readA_cnt <= 2'b0;
            readB_cnt <= 2'b0;

            base_addr_A <= 10'h000;      // A矩阵基地址：0x000
            base_addr_B <= 10'h100;      // B矩阵基地址：0x100
            base_addr_C <= 10'h200;      // C矩阵基地址：0x200
           
            mac_accumulator   <= 16'b0;
            write_back_active <= 1'b0;

            
            pool_row_cnt <= 2'b0;
            pool_col_cnt <= 2'b0;
            readA_done <= 1'b0;
            readB_done <= 1'b0;
            
            // Initialize result buffers
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    result_buffer[i][j] <= 8'b0;
                end
            end
            
            for (i = 0; i < 2; i = i + 1) begin
                for (j = 0; j < 2; j = j + 1) begin
                    pooled_buffer[i][j] <= 8'b0;
                end
            end
            
            // Initialize row/column buffers
            for (i = 0; i < 4; i = i + 1) begin
                a_row_buffer[i] <= 8'b0;
                b_col_buffer[i] <= 8'b0;
            end
            
            $display("MATMUL: Reset completed");
            
        end else begin
            case (current_state)
                IDLE: begin
                    ready_reg         <= 1'b1;
                    write_back_active <= 1'b0;
                    

                    pool_row_cnt      <= 2'b0;
                    pool_col_cnt      <= 2'b0;

                    readA_done        <= 1'b0;
                    readB_done        <= 1'b0;
                    readA_cnt         <= 2'b0;
                    readB_cnt         <= 2'b0;
                    mac_accumulator   <= 16'b0;
                    
                end

                READ_A: begin
                    ready_reg <= 1'b0;
                    row_cnt   <= 2'b0;
                    col_cnt   <= 2'b0;
                    inner_cnt <= 2'b0;
                    
                    $display("MATMUL: Starting matrix multiplication");
                    $display("MATMUL: Base addresses - A: 0x%h, B: 0x%h, C: 0x%h", 
                             base_addr_A, base_addr_B, base_addr_C);
                
                    // Fetch A matrix row
                    $display("MATMUL: READ_A - Reading A[%d] from 0x%h", 
                             row_cnt, base_addr_A + row_cnt);
            
                    // Capture A 1 row matrix data (row major)
                    a_row_buffer[0] <= mem_data_A[ 7: 0];
                    a_row_buffer[1] <= mem_data_A[15: 8];
                    a_row_buffer[2] <= mem_data_A[23:16];
                    a_row_buffer[3] <= mem_data_A[31:24];
                    
                    $display("MATMUL: WAIT_DATA_A - A[%d] = [%d, %d, %d, %d]", 
                             row_cnt, a_row_buffer[0], a_row_buffer[1], 
                             a_row_buffer[2], a_row_buffer[3]);
                    
                    readA_done <=  1'b1 ;
                end

                READ_B: begin
                    // Fetch B matrix column
                    $display("MATMUL: READ_B - Reading B[%d] from 0x%h", 
                             col_cnt, base_addr_B + col_cnt);
                    
                    // Capture 1 column B matrix data (column major)
                    b_col_buffer[0] <= mem_data_B[7:0];
                    b_col_buffer[1] <= mem_data_B[15:8];
                    b_col_buffer[2] <= mem_data_B[23:16];
                    b_col_buffer[3] <= mem_data_B[31:24];
                    
                    $display("MATMUL: WAIT_DATA_B - B[%d] = [%d, %d, %d, %d]", 
                             col_cnt, b_col_buffer[0], b_col_buffer[1], 
                             b_col_buffer[2], b_col_buffer[3]);
                    
                    // Reset MAC for new computation
                    mac_accumulator <= 16'b0;
                    
                    readB_done <= 1'b1;
                end

                MAC_COMPUTE: begin
                    // Multiply-accumulate computation
                    mac_accumulator <= mac_accumulator + (a_row_buffer[inner_cnt] * b_col_buffer[inner_cnt]);
                    inner_cnt <= inner_cnt + 1;

                    // Reset read done flags for next iteration
                    readA_done <= 1'b0;
                    readB_done <= 1'b0;
                    next_state = MAC_COMPUTE;
                    // 当完成一个内积计算时（4次乘累加）
                    if (inner_cnt == 2'b11) begin  // 完成4个元素的乘累加得到一个元素
                        // 将结果保存到result_buffer的对应位置
                        result_buffer[row_cnt][col_cnt] <= (mac_accumulator > 255) ? 8'hFF : mac_accumulator[7:0];
                        $display("MATMUL: STORE - C[%d][%d] = %d", row_cnt, col_cnt, 
                                (mac_accumulator > 255) ? 8'hFF : mac_accumulator[7:0]);
                    
                    
                    matmul_done <= ( readA_cnt == 2'b11 && readB_cnt == 2'b11 ) ? 1'b1 : 1'b0;
                    $display("MATMUL: MAC - inner_cnt=%d, a=%d, b=%d, product=%d, acc=%d", 
                             inner_cnt, a_row_buffer[inner_cnt], b_col_buffer[inner_cnt],
                             a_row_buffer[inner_cnt] * b_col_buffer[inner_cnt],
                             mac_accumulator + (a_row_buffer[inner_cnt] * b_col_buffer[inner_cnt]));
                    end      
                   
                end

                AVERAGE_POOL: begin
                    // Perform 2x2 average pooling
                    if (pool_row_cnt < 2 && pool_col_cnt < 2) begin
                        pooled_buffer[pool_row_cnt][pool_col_cnt] <= 
                               (result_buffer[pool_row_cnt*2][pool_col_cnt*2] +
                                result_buffer[pool_row_cnt*2][pool_col_cnt*2+1] +
                                result_buffer[pool_row_cnt*2+1][pool_col_cnt*2] +
                                result_buffer[pool_row_cnt*2+1][pool_col_cnt*2+1]) >> 2;
                        
                        $display("MATMUL: POOL - P[%d][%d] = (%d+%d+%d+%d)/4 = %d",
                                    pool_row_cnt, pool_col_cnt,
                                    result_buffer[pool_row_cnt*2][pool_col_cnt*2],
                                    result_buffer[pool_row_cnt*2][pool_col_cnt*2+1],
                                    result_buffer[pool_row_cnt*2+1][pool_col_cnt*2],
                                    result_buffer[pool_row_cnt*2+1][pool_col_cnt*2+1],
                                    (result_buffer[pool_row_cnt*2][pool_col_cnt*2] +
                                    result_buffer[pool_row_cnt*2][pool_col_cnt*2+1] +
                                    result_buffer[pool_row_cnt*2+1][pool_col_cnt*2] +
                                    result_buffer[pool_row_cnt*2+1][pool_col_cnt*2+1]) >> 2);
                        
                        if (pool_col_cnt == 2'b01) begin
                            pool_col_cnt <= 2'b0;
                            pool_row_cnt <= pool_row_cnt + 1;
                        end else begin
                            pool_col_cnt <= pool_col_cnt + 1;
                        end
                    end
                end
                
                WRITE_BACK: begin
                    // 激活写信号，将4个池化结果打包写入单个地址
                    write_back_active <= 1'b1;
                    
                    $display("MATMUL: Writing pooled results to single address 0x%h", base_addr_C);
                    $display("MATMUL: Pooled results = [%d, %d, %d, %d]", 
                            pooled_buffer[0][0], pooled_buffer[0][1],
                            pooled_buffer[1][0], pooled_buffer[1][1]);
                    
                    // 立即完成写回
                    write_back_active <= 1'b0;
                    ready_reg <= 1'b1;
                    
                    $display("MATMUL: Operation completed");
                end
            endcase
            
            // Write back logic
            if (write_back_active) begin
                
                    // All data written
                    write_back_active <= 1'b0;
                    $display("MATMUL: Write back completed");
                
                
        end
    end
    end
endmodule