class monitor;
    virtual fifo_if        vif;
    mailbox #(transaction) mon2scb;
    mailbox #(transaction) pending;

    function new(virtual fifo_if vif, mailbox #(transaction) mon2scb);
        this.vif     = vif;
        this.mon2scb = mon2scb;
        this.pending = new();
    endfunction

    task capture_controls();
        transaction txn;
        forever begin
            @(vif.monitor_cb);

            if (!vif.monitor_cb.wr_en && !vif.monitor_cb.rd_en) continue;
            if ( vif.monitor_cb.rd_en &&  vif.monitor_cb.empty)  continue;

            txn       = new();
            txn.wr_en = vif.monitor_cb.wr_en;
            txn.rd_en = vif.monitor_cb.rd_en;
            txn.full  = vif.monitor_cb.full;
            txn.empty = vif.monitor_cb.empty;
            txn.din   = vif.monitor_cb.wr_en ? vif.monitor_cb.din : 0;
            txn.dout  = 0;

            if (txn.rd_en)
                pending.put(txn);
            else begin
                txn.print("MON");
                mon2scb.put(txn);
            end
        end
    endtask

    task capture_dout();
        transaction txn;
        forever begin
            pending.get(txn);
            @(vif.monitor_cb);
            txn.dout = vif.monitor_cb.dout;
            txn.print("MON");
            mon2scb.put(txn);
        end
    endtask

    task main();
        fork
            capture_controls();
            capture_dout();
        join
    endtask
endclass