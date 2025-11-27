`timescale 1ps/1ps

module spi_master_tb;

   parameter DATA_WIDTH        = 8;
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
   wire [DATA_WIDTH-1:0] datao;

   assign dout = din;

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
      .datao(datao),
      .busy(busy),
      .done(done),
      .sclk(sclk),
      .csb(csb),
      .din(din),
      .dout(dout)
      );

   initial begin
      clk    = 0;
      resetb = 0;
      go     = 0;
      CPOL   = 0;
      CPHA   = 0;
      datai  = 0;

      $dumpfile("spi_master_only.vcd");
      $dumpvars(0, spi_master_tb);

      #20 resetb = 1;

      #20 $display("Testing spi_master only, all 4 modes");
      test_master_all_modes;

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

   task test_master_all_modes;
      integer mode;
      reg [DATA_WIDTH-1:0] patterns[0:3];
      integer i;
      reg pass;
      begin
         patterns[0] = 8'h00;
         patterns[1] = 8'hA5;
         patterns[2] = 8'h3C;
         patterns[3] = 8'hFF;

         pass = 1'b1;

         for (mode = 0; mode < 4; mode = mode + 1) begin
            CPOL = mode[1];
            CPHA = mode[0];

            $display("Mode %0d: CPOL=%0b CPHA=%0b", mode, CPOL, CPHA);

            for (i = 0; i < 4; i = i + 1) begin
               send(patterns[i]);
               if (datao !== patterns[i]) begin
                  $display("FAIL mode=%0d pattern=%0d: sent=0x%x recv=0x%x",
                           mode, i, patterns[i], datao);
                  pass = 0;
               end else begin
                  $display("PASS mode=%0d pattern=%0d: sent=0x%x recv=0x%x",
                           mode, i, patterns[i], datao);
               end
            end
         end

         if (pass)
           $display("MASTER-ONLY ALL-MODES TEST PASS");
         else
           $display("MASTER-ONLY ALL-MODES TEST FAIL");
      end
   endtask

endmodule
