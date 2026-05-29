class generator;
    rand transaction trans;
    mailbox #(transaction) gen2drv;
    int    repeat_count;
    event  drv2gen;

    function new(mailbox #(transaction) gen2drv, event drv2gen);
        this.gen2drv = gen2drv;
        this.drv2gen = drv2gen;
    endfunction

    task main();
        repeat (repeat_count) begin
            trans = new();
            if (!trans.randomize())
                $fatal(1, "[GEN] randomization failed");
            trans.print("GEN");
            gen2drv.put(trans);
        end
        -> drv2gen;
        $display("[GEN] Done — %0d transactions sent", repeat_count);
    endtask
endclass