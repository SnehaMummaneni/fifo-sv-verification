class scoreboard;
    mailbox #(transaction) mon2scb;
    int        no_trans;
    int        passed;
    int        failed;
    bit [31:0] ref_q[$];

    function new(mailbox #(transaction) mon2scb);
        this.mon2scb = mon2scb;
        this.passed  = 0;
        this.failed  = 0;
    endfunction

    task main();
        forever begin
            transaction trans;
            bit [31:0]  expected;

            mon2scb.get(trans);

            if (trans.wr_en && !trans.full) begin
                ref_q.push_back(trans.din);
                $display("[SCB] Pushed 0x%08h  depth=%0d",
                          trans.din, ref_q.size());
            end

            if (trans.rd_en && !trans.empty) begin
                if (ref_q.size() == 0) begin
                    $error("[SCB] FAIL — ref queue empty on read");
                    failed++;
                end else begin
                    expected = ref_q.pop_front();
                    no_trans++;
                    if (trans.dout === expected) begin
                        $display("[SCB] PASS expected=0x%08h got=0x%08h",
                                  expected, trans.dout);
                        passed++;
                    end else begin
                        $error("[SCB] FAIL expected=0x%08h got=0x%08h",
                                expected, trans.dout);
                        failed++;
                    end
                end
            end

            if (trans.full)  $display("[SCB] FIFO FULL");
            if (trans.empty) $display("[SCB] FIFO EMPTY");
        end
    endtask

    function void report();
        $display("================================");
        $display("[SCB] TOTAL CHECKS : %0d", no_trans);
        $display("[SCB] PASSED       : %0d", passed);
        $display("[SCB] FAILED       : %0d", failed);
        if (failed == 0)
            $display("[SCB] RESULT : ALL PASSED");
        else
            $display("[SCB] RESULT : %0d FAILURES", failed);
        $display("================================");
    endfunction
endclass