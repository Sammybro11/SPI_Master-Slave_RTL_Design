`timescale 1ns / 1ps

module spi_slave
#(parameter DATA_WIDTH=16,
    parameter INPUT_SAMPLE_AND_HOLD=1
)
(input CPOL, 
    input CPHA,

    input [DATA_WIDTH-1:0] datai,
    output [DATA_WIDTH-1:0] datao,

    output  dout,
    input din,
    input csb,
    input sclk,
    input rstb,
    output reg [DATA_WIDTH-1:0] rx_word,
    output reg rx_stb
);

reg [7:0] countp, countn;
reg [DATA_WIDTH-1:0] sro_p, sro_n, sri_p, sri_n;
wire [DATA_WIDTH-1:0] sro_p1,sro_n1;
reg first_p, first_n;
assign sro_p1 = (INPUT_SAMPLE_AND_HOLD) ? sro_p : datai << countp;
assign sro_n1 = (INPUT_SAMPLE_AND_HOLD) ? sro_n : datai << countn;

assign dout = (CPOL ^ CPHA) ? sro_p1[DATA_WIDTH-1] : sro_n1[DATA_WIDTH-1];
assign datao= (CPOL ^ CPHA) ? sri_n : sri_p;

always @(posedge sclk or posedge csb) begin
   if(csb) begin
      sro_p   <= datai;
      countp  <= 0;
      first_p <= 1'b1;
   end else begin
      if(INPUT_SAMPLE_AND_HOLD) begin
         if (CPHA && first_p) begin
            first_p <= 1'b0;
         end else begin
            sro_p <= sro_p << 1;
         end
      end else begin
         countp <= countp + 1;
      end
      sri_p <= { sri_p[DATA_WIDTH-2:0], din };
   end
end

always @(negedge sclk or posedge csb) begin
   if(csb) begin
      sro_n   <= datai;
      countn  <= 0;
      first_n <= 1'b1;
   end else begin
      if(INPUT_SAMPLE_AND_HOLD) begin
         if (CPHA && first_n) begin
            first_n <= 1'b0;
         end else begin
            sro_n <= sro_n << 1;
         end
      end else begin
         countn <= countn + 1;
      end
      sri_n <= { sri_n[DATA_WIDTH-2:0], din };
   end
end

always @(posedge csb or negedge rstb) begin
    if(!rstb) begin
        rx_word <= {DATA_WIDTH{1'b0}};
        rx_stb <= 1'b0;
    end else begin
        rx_word <= (CPOL ^ CPHA) ? sri_n : sri_p;
        rx_stb <= 1'b1;
    end
end

always @(negedge csb or negedge rstb) begin
    if(!rstb) begin
        rx_stb <= 1'b0;
    end else begin
        rx_stb <= 1'b0;
    end
end

endmodule
