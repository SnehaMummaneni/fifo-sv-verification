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
        // typed mailboxes passed to each component
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
        // wait for generator to finish all txns
        wait(drv2gen.triggered);
        // give driver time to finish last transaction
        repeat(20) @(posedge vif.clk);
        // give scoreboard time to process last entry
        #200;
    endtask

    task run();
        pre_test();
        test();
        post_test();
        scb.report();
        $finish;
    endtask
endclass
