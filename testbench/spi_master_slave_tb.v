`timescale 1ns / 1ps

module spi_master_slave_tb();

    parameter DATA_WIDTH=8;
    parameter CLK_DIVIDER_WIDTH=4;

    reg clk, resetb;
    wire [CLK_DIVIDER_WIDTH-1:0] clk_divider = 4;

    reg  go;

    wire [3:0] busy, done, sclk, csb, din, dout;
    reg [DATA_WIDTH-1:0] datai, datai_prev;
    wire [DATA_WIDTH-1:0] master_datao0, master_datao1, master_datao2, master_datao3;
    wire [DATA_WIDTH-1:0] slave_0, slave_data1, slave_data2, slave_data3;
    // Duplex mode ke wires
    reg  [DATA_WIDTH-1:0] slave_tx0, slave_tx1, slave_tx2, slave_tx3;
    wire [DATA_WIDTH-1:0] slave_rx0, slave_rx1, slave_rx2, slave_rx3;

    spi_master #(.DATA_WIDTH(DATA_WIDTH),
        .CLK_DIVIDER_WIDTH(CLK_DIVIDER_WIDTH))
        spi_master0
        (.clk(clk),
            .resetb(resetb),
            .CPOL(1'b0),
            .CPHA(1'b0),
            .clk_divider(clk_divider),
            .go(go),
            .datai(datai),
            .datao(master_datao0),
            .busy(busy[0]),
            .done(done[0]),
            .sclk(sclk[0]),
            .csb(csb[0]),
            .din(din[0]),
            .dout(dout[0])
        );

    spi_master #(.DATA_WIDTH(DATA_WIDTH),
        .CLK_DIVIDER_WIDTH(CLK_DIVIDER_WIDTH))
        spi_master1
        (.clk(clk),
            .resetb(resetb),
            .CPOL(1'b1),
            .CPHA(1'b0),
            .clk_divider(clk_divider),
            .go(go),
            .datai(datai),
            .datao(master_datao1),
            .busy(busy[1]),
            .done(done[1]),
            .sclk(sclk[1]),
            .csb(csb[1]),
            .din(din[1]),
            .dout(dout[1])
        );

    spi_master #(.DATA_WIDTH(DATA_WIDTH),
        .CLK_DIVIDER_WIDTH(CLK_DIVIDER_WIDTH))
        spi_master2
        (.clk(clk),
            .resetb(resetb),
            .CPOL(1'b0),
            .CPHA(1'b1),
            .clk_divider(clk_divider),
            .go(go),
            .datai(datai),
            .datao(master_datao2),
            .busy(busy[2]),
            .done(done[2]),
            .sclk(sclk[2]),
            .csb(csb[2]),
            .din(din[2]),
            .dout(dout[2])
        );

    spi_master #(.DATA_WIDTH(DATA_WIDTH),
        .CLK_DIVIDER_WIDTH(CLK_DIVIDER_WIDTH))
        spi_master3
        (.clk(clk),
            .resetb(resetb),
            .CPOL(1'b1),
            .CPHA(1'b1),
            .clk_divider(clk_divider),
            .go(go),
            .datai(datai),
            .datao(master_datao3),
            .busy(busy[3]),
            .done(done[3]),
            .sclk(sclk[3]),
            .csb(csb[3]),
            .din(din[3]),
            .dout(dout[3])
        );


    spi_slave #(.DATA_WIDTH(DATA_WIDTH))
    spi_slave0
    (.CPOL(1'b0),
        .CPHA(1'b0),
        .datai(slave_tx0),
        .datao(slave_rx0),
        .dout(dout[0]),
        .din(din[0]),
        .csb(csb[0]),
        .sclk(sclk[0]),
        .rstb(resetb),
        .rx_word(),
        .rx_stb()
    );

    spi_slave #(.DATA_WIDTH(DATA_WIDTH))
    spi_slave1
    (.CPOL(1'b1),
        .CPHA(1'b0),
        .datai(slave_tx1),
        .datao(slave_rx1),
        .dout(dout[1]),
        .din(din[1]),
        .csb(csb[1]),
        .sclk(sclk[1]),
        .rstb(resetb),
        .rx_word(),
        .rx_stb()
    );

    spi_slave #(.DATA_WIDTH(DATA_WIDTH))
    spi_slave2
    (.CPOL(1'b0),
        .CPHA(1'b1),
        .datai(slave_tx2),
        .datao(slave_rx2),
        .dout(dout[2]),
        .din(din[2]),
        .csb(csb[2]),
        .sclk(sclk[2]),
        .rstb(resetb),
        .rx_word(),
        .rx_stb()
    );

    spi_slave #(.DATA_WIDTH(DATA_WIDTH))
    spi_slave3
    (.CPOL(1'b1),
        .CPHA(1'b1),
        .datai(slave_tx3),
        .datao(slave_rx3),
        .dout(dout[3]),
        .din(din[3]),
        .csb(csb[3]),
        .sclk(sclk[3]),
        .rstb(resetb),
        .rx_word(),
        .rx_stb()
    );

    initial begin
        clk =  0;
        resetb = 0;
        go = 0;
        datai = 4'h0;

        $dumpfile("spi_test.vcd");
        $dumpvars(0, spi_master_slave_tb);

        #40 resetb = 1;

        #40 $display("Testing spi_master in Full Duplex Exchange");
        send(9);

        repeat(3) @(posedge clk);

        send(6);
        test_full_duplex();

        #40 $finish;
    end


    always #1 clk = !clk;


    task test_full_duplex;
       reg pass;
       reg [DATA_WIDTH-1:0] m_word;
       reg [DATA_WIDTH-1:0] exp0, exp1, exp2, exp3;
       begin
          pass    = 1'b1;
          m_word  = 8'hA5;

          slave_tx0 = 8'h11;
          slave_tx1 = 8'h22;
          slave_tx2 = 8'h33;
          slave_tx3 = 8'h44;

          send(8'h00);

          send(m_word);

          exp0 = slave_tx0;
          exp1 = slave_tx1;
          exp2 = slave_tx2;
          exp3 = slave_tx3;

          if (master_datao0 !== exp0) begin
             $display("FAIL mode=0: master_rx=0x%x expected=0x%x", master_datao0, exp0);
             pass = 0;
          end else begin
             $display("PASS mode=0: master_rx=0x%x expected=0x%x", master_datao0, exp0);
          end

          if (master_datao1 !== exp1) begin
             $display("FAIL mode=1: master_rx=0x%x expected=0x%x", master_datao1, exp1);
             pass = 0;
          end else begin
             $display("PASS mode=1: master_rx=0x%x expected=0x%x", master_datao1, exp1);
          end

          if (master_datao2 !== exp2) begin
             $display("FAIL mode=2: master_rx=0x%x expected=0x%x", master_datao2, exp2);
             pass = 0;
          end else begin
             $display("PASS mode=2: master_rx=0x%x expected=0x%x", master_datao2, exp2);
          end

          if (master_datao3 !== exp3) begin
             $display("FAIL mode=3: master_rx=0x%x expected=0x%x", master_datao3, exp3);
             pass = 0;
          end else begin
             $display("PASS mode=3: master_rx=0x%x expected=0x%x", master_datao3, exp3);
          end

          if (slave_rx0 !== m_word) begin
             $display("FAIL mode=0: slave_rx=0x%x expected=0x%x", slave_rx0, m_word);
             pass = 0;
          end else begin
             $display("PASS mode=0: slave_rx=0x%x expected=0x%x", slave_rx0, m_word);
          end

          if (slave_rx1 !== m_word) begin
             $display("FAIL mode=1: slave_rx=0x%x expected=0x%x", slave_rx1, m_word);
             pass = 0;
          end else begin
             $display("PASS mode=1: slave_rx=0x%x expected=0x%x", slave_rx1, m_word);
          end

          if (slave_rx2 !== m_word) begin
             $display("FAIL mode=2: slave_rx=0x%x expected=0x%x", slave_rx2, m_word);
             pass = 0;
          end else begin
             $display("PASS mode=2: slave_rx=0x%x expected=0x%x", slave_rx2, m_word);
          end

          if (slave_rx3 !== m_word) begin
             $display("FAIL mode=3: slave_rx=0x%x expected=0x%x", slave_rx3, m_word);
             pass = 0;
          end else begin
             $display("PASS mode=3: slave_rx=0x%x expected=0x%x", slave_rx3, m_word);
          end

          if (pass)
            $display("FULL-DUPLEX TEST PASS");
          else
            $display("FULL-DUPLEX TEST FAIL");
           end
    endtask

    task send;
        input [DATA_WIDTH-1:0] send_data;
        begin
            datai_prev <= datai;
            datai      <= send_data;
            @(posedge clk) go <= 1;
            @(posedge clk) go <= 0;
            @(posedge clk);
            while(|busy)
            @(posedge clk);
            @(posedge clk);
        end
    endtask

endmodule

