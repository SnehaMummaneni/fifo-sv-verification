module tb_top;

    bit clk;

    always #5 clk = ~clk;

    fifo_if intf (clk);

    // drive rst through interface — not as a port
    initial begin
        intf.rst = 1;
        repeat(5) @(posedge clk);
        intf.rst = 0;
    end

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

    // generous watchdog — 100 txns + directed tests need time
    initial begin
        #2_000_000;
        $display("[TB] TIMEOUT — forcing finish");
        $finish;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;
    end

endmodule