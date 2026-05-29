module tb_top;

    bit clk;
    bit rst;

    always #5 clk = ~clk;

    // active-HIGH reset: assert for 5 cycles then release
    initial begin
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
    end

    fifo_if intf (clk, rst);

    test_prog t1 (intf);

    fifo DUT (
        .data_op (intf.dout),
        .full    (intf.full),
        .empty   (intf.empty),
        .data_in (intf.din),
        .wr_en   (intf.wr_en),
        .rd_en   (intf.rd_en),
        .clk     (intf.clk),
        .rst     (intf.rst)
    );

    // safety watchdog
    initial begin
        #100_000;
        $display("[TB] TIMEOUT — forcing finish");
        $finish;
    end

endmodule