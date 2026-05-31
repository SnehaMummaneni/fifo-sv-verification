class transaction;
    rand bit [31:0] din;
    rand bit        wr_en;
    rand bit        rd_en;
    bit [31:0]      dout;
    bit             full;
    bit             empty;

    constraint c_ops {
        {wr_en, rd_en} dist {
            2'b10 := 50,
            2'b01 := 40,
            2'b00 := 10
          
        };
    }

    function void print(string tag = "TXN");
        $display("[%s] wr=%0b rd=%0b din=0x%08h | dout=0x%08h full=%0b empty=%0b",
                  tag, wr_en, rd_en, din, dout, full, empty);
    endfunction
endclass