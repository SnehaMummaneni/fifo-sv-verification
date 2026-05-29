interface fifo_if (input logic clk, input logic rst);

    logic [31:0] din;
    logic        wr_en;
    logic        rd_en;
    logic [31:0] dout;
    logic        full;
    logic        empty;

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

    // ── ASSERTIONS (raw signals — race-free in Observed region) ──
    property p_no_overflow;
        @(posedge clk) disable iff (rst)
        not (wr_en && full);
    endproperty
    assert_no_overflow: assert property(p_no_overflow)
        else $error("[ASSERT] OVERFLOW at time %0t", $time);

    property p_no_underflow;
        @(posedge clk) disable iff (rst)
        not (rd_en && empty);
    endproperty
    assert_no_underflow: assert property(p_no_underflow)
        else $error("[ASSERT] UNDERFLOW at time %0t", $time);

    property p_full_empty_mutex;
        @(posedge clk) disable iff (rst)
        not (full && empty);
    endproperty
    assert_full_empty_mutex: assert property(p_full_empty_mutex)
        else $fatal(1, "[ASSERT] full AND empty both 1");

    property p_reset_empties;
        @(posedge clk)
        $fell(rst) |=> empty;   // active-HIGH rst: fell = reset released
    endproperty
    assert_reset_empties: assert property(p_reset_empties)
        else $error("[ASSERT] not empty after reset at %0t", $time);

    // ── COVERAGE ─────────────────────────────────────────────────
    covergroup fifo_cg @(posedge clk);
        option.per_instance = 1;
        cp_wr:    coverpoint wr_en;
        cp_rd:    coverpoint rd_en;
        cp_full:  coverpoint full;
        cp_empty: coverpoint empty;
        cp_op: coverpoint {wr_en, rd_en} {
            bins write_only = {2'b10};
            bins read_only  = {2'b01};
        }
        cx_op_full:  cross cp_op, cp_full;
        cx_op_empty: cross cp_op, cp_empty;
    endgroup
    fifo_cg cg_inst = new();

endinterface
