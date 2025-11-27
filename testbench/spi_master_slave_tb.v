`timescale 1ps/1ps

module spi_master_slave_tb();

   parameter DATA_WIDTH       = 8;
   parameter CLK_DIVIDER_WIDTH = 4;
   reg  clk;
   reg  resetb;
   wire [CLK_DIVIDER_WIDTH-1:0] clk_divider = 4;
   reg  go;
   reg  CPOL;
   reg  CPHA;

   wire busy;
   wire done;
   wire sclk;
   wire csb;
   wire din;
   wire dout;

   reg  [DATA_WIDTH-1:0] datai;
   reg  [DATA_WIDTH-1:0] slave_tx;
   wire [DATA_WIDTH-1:0] master_datao;
   wire [DATA_WIDTH-1:0] slave_rx;

   spi_master #(.DATA_WIDTH(DATA_WIDTH),
                .CLK_DIVIDER_WIDTH(CLK_DIVIDER_WIDTH))
   spi_master0
     (.clk(clk),
      .resetb(resetb),
      .CPOL(CPOL),
      .CPHA(CPHA),
      .clk_divider(clk_divider),
      .go(go),
      .datai(datai),
      .datao(master_datao),
      .busy(busy),
      .done(done),
      .sclk(sclk),
      .csb(csb),
      .din(din),
      .dout(dout)
      );

   spi_slave #(.DATA_WIDTH(DATA_WIDTH))
   spi_slave0
     (.CPOL(CPOL),
      .CPHA(CPHA),
      .datai(slave_tx),
      .datao(slave_rx),
      .dout(dout),
      .din(din),
      .csb(csb),
      .sclk(sclk),
      .rstb(resetb),
      .rx_word(),
      .rx_stb()
      );

   initial begin
      clk      = 0;
      resetb   = 0;
      go       = 0;
      CPOL     = 0;
      CPHA     = 0;
      datai    = 0;
      slave_tx = 0;
      $dumpfile("spi_test.vcd");
      $dumpvars(0, spi_master_slave_tb);
      #40 resetb = 1;

      #40 $display("Testing spi_master in Full Duplex Exchange");
      test_full_duplex();
      #40 $finish;
   end

   always #1 clk = !clk;

   task send;
      input [DATA_WIDTH-1:0] send_data;
      begin
         datai <= send_data;
         @(posedge clk) go <= 1;
         @(posedge clk) go <= 0;
         @(posedge clk);
         while (busy)
           @(posedge clk);
         @(posedge clk);
      end
   endtask

   task test_full_duplex;
      integer mode;
      reg pass;
      reg [DATA_WIDTH-1:0] m_word;
      reg [DATA_WIDTH-1:0] slave_pattern[0:3];
      begin
         pass   = 1'b1;
         m_word = 8'hA5;

         slave_pattern[0] = 8'h11;
         slave_pattern[1] = 8'h22;
         slave_pattern[2] = 8'h33;
         slave_pattern[3] = 8'h44;

         for (mode = 0; mode < 4; mode = mode + 1) begin
            CPOL = mode[1];
            CPHA = mode[0];

            slave_tx = slave_pattern[mode];

            send(8'h00);
            send(m_word);

            if (master_datao !== slave_tx) begin
               $display("FAIL mode=%0d (CPOL=%0b, CPHA=%0b): master_rx=0x%x expected=0x%x",
                        mode, CPOL, CPHA, master_datao, slave_tx);
               pass = 0;
            end else begin
               $display("PASS mode=%0d (CPOL=%0b, CPHA=%0b): master_rx=0x%x expected=0x%x",
                        mode, CPOL, CPHA, master_datao, slave_tx);
            end

            if (slave_rx !== m_word) begin
               $display("FAIL mode=%0d (CPOL=%0b, CPHA=%0b): slave_rx=0x%x expected=0x%x",
                        mode, CPOL, CPHA, slave_rx, m_word);
               pass = 0;
            end else begin
               $display("PASS mode=%0d (CPOL=%0b, CPHA=%0b): slave_rx=0x%x expected=0x%x",
                        mode, CPOL, CPHA, slave_rx, m_word);
            end
         end

         if (pass)
           $display("FULL-DUPLEX TEST PASS");
         else
           $display("FULL-DUPLEX TEST FAIL");
      end
   endtask

endmodule
