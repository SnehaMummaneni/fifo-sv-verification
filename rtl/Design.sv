
module fifo (
    output reg [31:0] data_op,
    output reg        full,
    output reg        empty,
    input  [31:0]     data_in,
    input             wr_en,
    input             rd_en,
    input             clk,
    input             rst
);
    reg [31:0] ram [31:0];
    integer    wr_ptr;
    integer    rd_ptr;
    integer    count;
    integer    next_count;   // combinational lookahead

   
    always @(*) begin
        if (wr_en && !full && rd_en && !empty)
            next_count = count;         
        else if (wr_en && !full)
            next_count = count + 1;
        else if (rd_en && !empty)
            next_count = count - 1;
        else
            next_count = count;
    end

    always @(posedge clk) begin
        if (rst) begin
            data_op <= 32'b0;
            wr_ptr  <= 0;
            rd_ptr  <= 0;
            count   <= 0;
            full    <= 1'b0;
            empty   <= 1'b1;
        end
        else begin
            if (wr_en && !full) begin
                ram[wr_ptr] <= data_in;
                wr_ptr      <= (wr_ptr + 1) % 32;
            end

            if (rd_en && !empty) begin
                data_op <= ram[rd_ptr];
                rd_ptr  <= (rd_ptr + 1) % 32;
            end

            count <= next_count;
           
            full  <= (next_count == 32);
            empty <= (next_count == 0);
        end
    end
endmodule