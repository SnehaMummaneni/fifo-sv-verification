program test_prog (fifo_if intf);
    environment env;

    initial begin
        env = new(intf);

        // ── PHASE 1: Random test ─────────────────────────
        $display("\n===== PHASE 1: Random Test =====");
        env.gen.repeat_count = 100;
        env.run();

        // KEY FIX: stop all threads before directed tests
        // random driver was staying alive and interfering
        env.stop_threads();

        // ── PHASE 2: Fill FIFO completely ────────────────
        test_fill(intf, env);

        // ── PHASE 3: Drain FIFO completely ───────────────
        test_drain(intf, env);

        // ── PHASE 4: Idle cycles ─────────────────────────
        test_idle(intf);

        // ── PHASE 5: Reset mid-operation ─────────────────
        test_reset(intf, env);

        // ── FINAL REPORT ─────────────────────────────────
        repeat(5) @(posedge intf.clk);
        env.scb.report();
        $display("--------------------------------");
        $display("Covergroup Coverage = %0.2f%%",
                  intf.cg_inst.get_coverage());
        $display("  cp_wr       = %0.2f%%", intf.cg_inst.cp_wr.get_coverage());
        $display("  cp_rd       = %0.2f%%", intf.cg_inst.cp_rd.get_coverage());
        $display("  cp_full     = %0.2f%%", intf.cg_inst.cp_full.get_coverage());
        $display("  cp_empty    = %0.2f%%", intf.cg_inst.cp_empty.get_coverage());
        $display("  cp_op       = %0.2f%%", intf.cg_inst.cp_op.get_coverage());
        $display("  cx_op_full  = %0.2f%%", intf.cg_inst.cx_op_full.get_coverage());
        $display("  cx_op_empty = %0.2f%%", intf.cg_inst.cx_op_empty.get_coverage());
        $display("--------------------------------");
        $finish;
    end

    // ── DIRECTED TEST 1: Fill FIFO to full ───────────────
    task test_fill(virtual fifo_if vif, environment env);
        $display("\n----- DIRECTED: Fill FIFO to full -----");

        // reset first — clears leftover data from random phase
        vif.rst = 1;
        repeat(5) @(posedge vif.clk);
        vif.rst = 0;
        repeat(2) @(posedge vif.clk);
        env.scb.ref_q = {};
        $display("[TEST] Reset done — ref model cleared");

        // write exactly 32 times into a clean FIFO
        repeat(32) begin
            @(posedge vif.clk); #1;
            vif.wr_en = 1;
            vif.rd_en = 0;
            vif.din   = $urandom();
        end
        @(posedge vif.clk); #1;
        vif.wr_en = 0;

        // count-based full flag needs 2 cycles to update after last write
        repeat(3) @(posedge vif.clk);

        if (vif.full)
            $display("[TEST] PASS — FIFO full after 32 writes");
        else
            $error("[TEST] FAIL — FIFO should be full (count=%0d)", 32);

        // attempt write while full
        // this hits cx_op_full write_only+is_full cross bin
        // overflow assertion fires here — EXPECTED, proves DUT protection works
        @(posedge vif.clk); #1;
        vif.wr_en = 1;
        vif.din   = 32'hDEADBEEF;
        @(posedge vif.clk); #1;
        vif.wr_en = 0;
        repeat(3) @(posedge vif.clk);
    endtask

    // ── DIRECTED TEST 2: Drain FIFO to empty ─────────────
    task test_drain(virtual fifo_if vif, environment env);
        $display("\n----- DIRECTED: Drain FIFO to empty -----");

        // read 32 times — FIFO has 32 entries from test_fill
        repeat(32) begin
            @(posedge vif.clk); #1;
            if (!vif.empty) begin
                vif.rd_en = 1;
                vif.wr_en = 0;
            end else begin
                vif.rd_en = 0;
            end
        end
        @(posedge vif.clk); #1;
        vif.rd_en = 0;

        // count-based empty flag needs 2 cycles to update
        repeat(3) @(posedge vif.clk);

        if (vif.empty)
            $display("[TEST] PASS — FIFO empty after 32 reads");
        else
            $error("[TEST] FAIL — FIFO should be empty");

        // attempt read while empty
        // this hits cx_op_empty read_only+is_empty cross bin
        // underflow assertion fires here — EXPECTED
        @(posedge vif.clk); #1;
        vif.rd_en = 1;
        @(posedge vif.clk); #1;
        vif.rd_en = 0;
        repeat(3) @(posedge vif.clk);
    endtask

    // ── DIRECTED TEST 3: Idle cycles ─────────────────────
    task test_idle(virtual fifo_if vif);
        $display("\n----- DIRECTED: Idle cycles -----");
        // wr_en=0 rd_en=0 for 20 cycles
        // hits cp_op neither = 2'b00 bin
        repeat(20) begin
            @(posedge vif.clk); #1;
            vif.wr_en = 0;
            vif.rd_en = 0;
            vif.din   = 0;
        end
        $display("[TEST] Idle done — neither bin covered");
    endtask

    // ── DIRECTED TEST 4: Reset mid-operation ─────────────
    task test_reset(virtual fifo_if vif, environment env);
        $display("\n----- DIRECTED: Reset mid-operation -----");

        // write 10 entries
        repeat(10) begin
            @(posedge vif.clk); #1;
            vif.wr_en = 1;
            vif.rd_en = 0;
            vif.din   = $urandom();
        end
        @(posedge vif.clk); #1;
        vif.wr_en = 0;
        repeat(2) @(posedge vif.clk);

        $display("[TEST] 10 entries written — applying reset");

        // assert reset
        vif.rst = 1;
        repeat(5) @(posedge vif.clk);
        vif.rst = 0;

        // $fell(rst) |=> empty: empty valid NEXT cycle after rst falls
        repeat(3) @(posedge vif.clk);

        if (vif.empty && !vif.full)
            $display("[TEST] PASS — FIFO empty after mid-reset");
        else
            $error("[TEST] FAIL — not empty after reset: empty=%0b full=%0b",
                    vif.empty, vif.full);

        env.scb.ref_q = {};
        $display("[TEST] Ref model cleared after reset");
        repeat(3) @(posedge vif.clk);
    endtask

endprogram

// ============================================================
// 9. TB_TOP
// ============================================================
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