class driver;
    int                    no_trans;
    virtual fifo_if        vif;
    mailbox #(transaction) gen2drv;

    function new(virtual fifo_if vif, mailbox #(transaction) gen2drv);
        this.vif     = vif;
        this.gen2drv = gen2drv;
    endfunction

    // wait for active-HIGH reset to complete
    task reset();
        $display("[DRV] Waiting for reset");
        vif.driver_cb.wr_en <= 0;
        vif.driver_cb.rd_en <= 0;
        vif.driver_cb.din   <= 0;
        wait(vif.rst  == 1);   // wait rst goes HIGH
        wait(vif.rst  == 0);   // wait rst goes LOW (released)
        $display("[DRV] Reset done");
    endtask

    task drive();
        forever begin
            transaction trans;
            gen2drv.get(trans);

            @(vif.driver_cb);   // sync to clock edge

            // default: deassert everything
            vif.driver_cb.wr_en <= 0;
            vif.driver_cb.rd_en <= 0;
            vif.driver_cb.din   <= 0;

            if (trans.wr_en) begin
                if (!vif.driver_cb.full) begin
                    vif.driver_cb.wr_en <= 1;
                    vif.driver_cb.din   <= trans.din;
                    trans.full          = vif.driver_cb.full;
                    trans.empty         = vif.driver_cb.empty;
                    $display("[DRV] WRITE din=0x%08h", trans.din);
                end else begin
                    $display("[DRV] full — suppressing write");
                end
            end

            if (trans.rd_en) begin
                if (!vif.driver_cb.empty) begin
                    vif.driver_cb.rd_en <= 1;
                    @(vif.driver_cb);               // assert for one cycle
                    vif.driver_cb.rd_en <= 0;
                    @(vif.driver_cb);               // dout valid after this edge
                    trans.dout  = vif.driver_cb.dout;
                    trans.full  = vif.driver_cb.full;
                    trans.empty = vif.driver_cb.empty;
                    $display("[DRV] READ  dout=0x%08h", trans.dout);
                end else begin
                    $display("[DRV] empty — suppressing read");
                end
            end

            trans.print("DRV");
            no_trans++;
        end
    endtask

    task main();
        forever begin
            fork
                begin wait(vif.rst == 1); end   // watch for reset
                begin drive();            end
            join_any
            disable fork;
        end
    endtask
endclass