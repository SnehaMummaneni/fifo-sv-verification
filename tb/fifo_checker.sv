module fifo_checker (
    input        clk,
    input        rst,       
    input        wr_en,
    input        rd_en,
    input [31:0] data_in,
    input [31:0] data_op,
    input        full,
    input        empty,
    input integer count,   
    input integer wr_ptr,
    input integer rd_ptr
);


  property p_no_overflow;
    @(posedge clk) disable iff (rst)
    not (wr_en && full);
  endproperty
  assert_no_overflow: assert property (p_no_overflow)
    else $error("[ASSERT] OVERFLOW at time %0t", $time);


  property p_no_underflow;
    @(posedge clk) disable iff (rst)
    not (rd_en && empty);
  endproperty
  assert_no_underflow: assert property (p_no_underflow)
    else $error("[ASSERT] UNDERFLOW at time %0t", $time);


  property p_full_empty_mutex;
    @(posedge clk) disable iff (rst)
    not (full && empty);
  endproperty
  assert_full_empty_mutex: assert property (p_full_empty_mutex)
    else $fatal(1, "[ASSERT] full AND empty both 1");

  
  property p_reset_empties;
    @(posedge clk)
    $fell(rst) |=> empty;
  endproperty
  assert_reset_empties: assert property (p_reset_empties)
    else $error("[ASSERT] not empty after reset at %0t", $time);

  property p_count_in_bounds;
    @(posedge clk) disable iff (rst)
    (count >= 0) && (count <= 32);
  endproperty
  assert_count_in_bounds: assert property (p_count_in_bounds)
    else $error("[ASSERT] count OUT OF BOUNDS (%0d) at time %0t — storage pointer corruption", count, $time);

  property p_full_matches_count;
    @(posedge clk) disable iff (rst)
    (count == 32) |-> full;
  endproperty
  assert_full_matches_count: assert property (p_full_matches_count)
    else $error("[ASSERT] count==32 but full flag not set at %0t", $time);

  property p_empty_matches_count;
    @(posedge clk) disable iff (rst)
    (count == 0) |-> empty;
  endproperty
  assert_empty_matches_count: assert property (p_empty_matches_count)
    else $error("[ASSERT] count==0 but empty flag not set at %0t", $time);

  property p_wr_ptr_wraps;
    @(posedge clk) disable iff (rst)
    (wr_en && !full && wr_ptr == 31) |=> (wr_ptr == 0);
  endproperty
  assert_wr_ptr_wraps: assert property (p_wr_ptr_wraps)
    else $error("[ASSERT] wr_ptr did not wrap correctly at boundary, time %0t", $time);

  property p_rd_ptr_wraps;
    @(posedge clk) disable iff (rst)
    (rd_en && !empty && rd_ptr == 31) |=> (rd_ptr == 0);
  endproperty
  assert_rd_ptr_wraps: assert property (p_rd_ptr_wraps)
    else $error("[ASSERT] rd_ptr did not wrap correctly at boundary, time %0t", $time);

  // ---------------------------------------------------------------------
  // COVER PROPERTIES — corner-case sequences (feed a formal/coverage report)
  // ---------------------------------------------------------------------
  cover_back_to_back_full: cover property (
    @(posedge clk) disable iff (rst) full ##1 full ##1 full
  );
  cover_reset_mid_transaction: cover property (
    @(posedge clk) (wr_en || rd_en) ##1 $rose(rst)
  );
  cover_simul_rw_at_boundary: cover property (
    @(posedge clk) disable iff (rst) (count == 31) && wr_en && rd_en
  );
  cover_single_entry_roundtrip: cover property (
    @(posedge clk) disable iff (rst)
    (count == 0) ##[1:5] (wr_en) ##[1:5] (count == 1) ##[1:5] (rd_en) ##[1:5] (count == 0)
  );

  // ---------------------------------------------------------------------
  // FUNCTIONAL + CROSS COVERAGE
  // ---------------------------------------------------------------------
  covergroup fifo_cg @(posedge clk);
    option.per_instance = 1;

    cp_wr    : coverpoint wr_en;
    cp_rd    : coverpoint rd_en;
    cp_full  : coverpoint full;
    cp_empty : coverpoint empty;

    cp_op : coverpoint {wr_en, rd_en} {
      bins write_only = {2'b10};
      bins read_only  = {2'b01};
      bins neither    = {2'b00};
      bins simul_rw   = {2'b11};   // now tracked instead of excluded —
     // your DUT does not forbid this combination,
     // it's a legal case worth covering explicitly
    }

    cp_count : coverpoint count {
      bins empty_zone = {0};
      bins low_zone   = {[1:8]};
      bins mid_zone   = {[9:23]};
      bins high_zone  = {[24:31]};
      bins full_zone  = {32};
    }

    cx_op_full   : cross cp_op, cp_full;    // catches illegal write-attempt-while-full patterns
    cx_op_empty  : cross cp_op, cp_empty;   // catches illegal read-attempt-while-empty patterns
    cx_count_op  : cross cp_count, cp_op;   // every operation type at every fill level
  endgroup
  fifo_cg cg_inst = new();

endmodule

bind fifo fifo_checker u_fifo_checker (
    .clk     (clk),
    .rst     (rst),
    .wr_en   (wr_en),
    .rd_en   (rd_en),
    .data_in (data_in),
    .data_op (data_op),
    .full    (full),
    .empty   (empty),
    .count   (count),
    .wr_ptr  (wr_ptr),
    .rd_ptr  (rd_ptr)
);