interface fifo_if (input logic clk);

    logic [31:0] din;
    logic        wr_en;
    logic        rd_en;
    logic [31:0] dout;
    logic        full;
    logic        empty;
    logic        rst;  

    clocking driver_cb @(posedge clk);
        default input #1 output #1;
        output wr_en, rd_en, din;
        input  dout, full, empty;
    endclocking

    clocking monitor_cb @(posedge clk);
        default input #1;
        input wr_en, rd_en, din, dout, full, empty;
    endclocking

    modport DRIVER  (clocking driver_cb,  input clk, rst);
    modport MONITOR (clocking monitor_cb, input clk, rst);


endinterface
