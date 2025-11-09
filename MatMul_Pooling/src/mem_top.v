module mem_top (
    input  wire        clk,
    input  wire        rstn,
    
    // Port A - Matrix A interface
    input  wire        read_en_A,
    input  wire [9:0]  addr_A,      
    output reg  [31:0] data_out_A,
    
    // Port B - Matrix B interface  
    input  wire        read_en_B,
    input  wire [9:0]  addr_B,      
    output reg  [31:0] data_out_B,
    
    // Port C - Result write interface
    input  wire        write_en_C,
    input  wire [9:0]  addr_C,      
    input  wire [31:0] data_in_C
);

    // Memory declaration - 1024x32 bit memory
    reg [31:0] memory [0:1023];
    
    // Integer for initialization
    integer k;
    
    // Initialize memory with test data
    initial begin
        // Initialize all memory to 0
        for (k = 0; k < 1024; k = k + 1) begin
            memory[k] = 32'b0;
        end
        
        $display("Initializing memory with test data...");
        
        // Matrix A (4x4) - Row major order, addresses 0x000-0x003
        // Row 0: 1, 2, 3, 4
        memory[10'h000] = {8'd4, 8'd3, 8'd2, 8'd1};
        $display("Memory[0x000] = 0x%h -> [%d, %d, %d, %d]", 
                 memory[10'h000], 8'd1, 8'd2, 8'd3, 8'd4);
        
        // Row 1: 5, 6, 7, 8
        memory[10'h001] = {8'd8, 8'd7, 8'd6, 8'd5};
        $display("Memory[0x001] = 0x%h -> [%d, %d, %d, %d]", 
                 memory[10'h001], 8'd5, 8'd6, 8'd7, 8'd8);
        
        // Row 2: 9, 10, 11, 12
        memory[10'h002] = {8'd12, 8'd11, 8'd10, 8'd9};
        $display("Memory[0x002] = 0x%h -> [%d, %d, %d, %d]", 
                 memory[10'h002], 8'd9, 8'd10, 8'd11, 8'd12);
        
        // Row 3: 13, 14, 15, 16
        memory[10'h003] = {8'd16, 8'd15, 8'd14, 8'd13};
        $display("Memory[0x003] = 0x%h -> [%d, %d, %d, %d]", 
                 memory[10'h003], 8'd13, 8'd14, 8'd15, 8'd16);
        
        // Matrix B (4x4) - Column major order, addresses 0x100-0x103
        // Col 0: 1, 2, 3, 4
        memory[10'h100] = {8'd4, 8'd3, 8'd2, 8'd1};
        $display("Memory[0x100] = 0x%h -> [%d, %d, %d, %d]", 
                 memory[10'h100], 8'd1, 8'd2, 8'd3, 8'd4);
        
        // Col 1: 5, 6, 7, 8
        memory[10'h101] = {8'd8, 8'd7, 8'd6, 8'd5};
        $display("Memory[0x101] = 0x%h -> [%d, %d, %d, %d]", 
                 memory[10'h101], 8'd5, 8'd6, 8'd7, 8'd8);
        
        // Col 2: 9, 10, 11, 12
        memory[10'h102] = {8'd12, 8'd11, 8'd10, 8'd9};
        $display("Memory[0x102] = 0x%h -> [%d, %d, %d, %d]", 
                 memory[10'h102], 8'd9, 8'd10, 8'd11, 8'd12);
        
        // Col 3: 13, 14, 15, 16
        memory[10'h103] = {8'd16, 8'd15, 8'd14, 8'd13};
        $display("Memory[0x103] = 0x%h -> [%d, %d, %d, %d]", 
                 memory[10'h103], 8'd13, 8'd14, 8'd15, 8'd16);
        
        $display("Memory initialization completed.");
    end

    // Port A read logic
    always @(posedge clk) begin
        if (read_en_A) begin
            data_out_A <= memory[addr_A];
            $display("MEM_READ_A: addr=0x%h, data=0x%h -> [%d, %d, %d, %d]", 
                     addr_A, memory[addr_A], 
                     memory[addr_A][7:0], memory[addr_A][15:8], 
                     memory[addr_A][23:16], memory[addr_A][31:24]);
        end
    end
    
    // Port B read logic  
    always @(posedge clk) begin
        if (read_en_B) begin
            data_out_B <= memory[addr_B];
            $display("MEM_READ_B: addr=0x%h, data=0x%h -> [%d, %d, %d, %d]", 
                     addr_B, memory[addr_B],
                     memory[addr_B][7:0], memory[addr_B][15:8],
                     memory[addr_B][23:16], memory[addr_B][31:24]);
        end
    end
    
    // Port C write logic
    always @(posedge clk) begin
        if (write_en_C) begin
            memory[addr_C] <= data_in_C;
            $display("MEM_WRITE_C: addr=0x%h, data=0x%h -> [%d, %d, %d, %d]", 
                     addr_C, data_in_C,
                     data_in_C[7:0], data_in_C[15:8],
                     data_in_C[23:16], data_in_C[31:24]);
        end
    end

endmodule