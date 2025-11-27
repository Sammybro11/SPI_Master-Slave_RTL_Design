`timescale 1ps/1ps

module spi_slave_tb;

   parameter DATA_WIDTH = 8;

   reg  CPOL;
   reg  CPHA;

   reg  rstb;
   reg  csb;
   reg  sclk;
   reg  din;
   wire dout;

   reg  [DATA_WIDTH-1:0] datai;
   wire [DATA_WIDTH-1:0] datao;

   wire [DATA_WIDTH-1:0] rx_word;
   wire                  rx_stb;

   spi_slave #(.DATA_WIDTH(DATA_WIDTH))
   spi_slave0
     (.CPOL(CPOL),
      .CPHA(CPHA),
      .datai(datai),
      .datao(datao),
      .dout(dout),
      .din(din),
      .csb(csb),
      .sclk(sclk),
      .rstb(rstb),
      .rx_word(rx_word),
      .rx_stb(rx_stb)
      );

   initial begin
      CPOL = 0;
      CPHA = 0;
      rstb = 0;
      csb  = 1;
      sclk = 0;
      din  = 0;
      datai = 8'h55;

      $dumpfile("spi_slave_only.vcd");
      $dumpvars(0, spi_slave_tb);

      #20 rstb = 1;

      #20 $display("Testing spi_slave only, all 4 modes (RX path)");
      test_slave_all_modes;

      #40 $finish;
   end

   task drive_edge;
      input leading;
      begin
         if (leading) begin
            if (CPOL == 0)
               sclk = 1;
            else
               sclk = 0;
         end else begin
            if (CPOL == 0)
               sclk = 0;
            else
               sclk = 1;
         end
      end
   endtask

   task send_frame_mosi;
      input [DATA_WIDTH-1:0] mosi_word;
      integer i;
      begin
         csb = 0;
         sclk = CPOL;

         if (CPHA == 0) begin
            for (i = DATA_WIDTH-1; i >= 0; i = i - 1) begin
               din = mosi_word[i];
               #1 drive_edge(1);
               #1 drive_edge(0);
            end
         end else begin
            drive_edge(1);
            drive_edge(0);
            for (i = DATA_WIDTH-1; i >= 0; i = i - 1) begin
               din = mosi_word[i];
               #1 drive_edge(1);
               #1 drive_edge(0);
            end
         end

         csb = 1;
         sclk = CPOL;
         #2;
      end
   endtask

   task test_slave_all_modes;
      integer mode;
      reg [DATA_WIDTH-1:0] mosi_patterns[0:3];
      integer i;
      reg pass;
      begin
         mosi_patterns[0] = 8'h00;
         mosi_patterns[1] = 8'h5A;
         mosi_patterns[2] = 8'hC3;
         mosi_patterns[3] = 8'hFF;

         pass = 1'b1;

         for (mode = 0; mode < 4; mode = mode + 1) begin
            CPOL = mode[1];
            CPHA = mode[0];

            $display("Mode %0d: CPOL=%0b CPHA=%0b", mode, CPOL, CPHA);

            for (i = 0; i < 4; i = i + 1) begin
               send_frame_mosi(mosi_patterns[i]);
               if (datao !== mosi_patterns[i]) begin
                  $display("FAIL slave RX mode=%0d pattern=%0d: mosi=0x%x rx=0x%x",
                           mode, i, mosi_patterns[i], datao);
                  pass = 0;
               end else begin
                  $display("PASS slave RX mode=%0d pattern=%0d: mosi=0x%x rx=0x%x",
                           mode, i, mosi_patterns[i], datao);
               end
            end
         end

         if (pass)
           $display("SLAVE-ONLY ALL-MODES TEST PASS");
         else
           $display("SLAVE-ONLY ALL-MODES TEST FAIL");
      end
   endtask

endmodule
