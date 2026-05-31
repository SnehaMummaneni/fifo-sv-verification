class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv;
    mailbox #(transaction) mon2scb;
    event                  drv2gen;

    virtual fifo_if vif;

    function new(virtual fifo_if vif);
        this.vif = vif;
        gen2drv  = new();
        mon2scb  = new();
        gen = new(gen2drv, drv2gen);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2scb);
        scb = new(mon2scb);
    endfunction

    task pre_test();
        drv.reset();
    endtask

    task test();
        fork
            gen.main();
            drv.main();
            mon.main();
            scb.main();
        join_none
    endtask

    task post_test();
        wait(drv2gen.triggered);
        repeat(20) @(posedge vif.clk);
        #200;
    endtask

    // KEY FIX: stop all background threads before directed tests
    task stop_threads();
        disable fork;
        $display("[ENV] All background threads stopped");
        // flush pending mailbox entries
        begin
            transaction t;
            while (gen2drv.num() > 0) gen2drv.get(t);
        end
        // deassert all signals
        @(posedge vif.clk); #1;
        vif.wr_en = 0;
        vif.rd_en = 0;
        vif.din   = 0;
        repeat(5) @(posedge vif.clk);
    endtask

    task run();
        pre_test();
        test();
        post_test();
    endtask
endclass