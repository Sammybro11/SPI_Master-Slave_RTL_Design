module spi_master
#(parameter DATA_WIDTH=16,
    NUM_PORTS=1,
    CLK_DIVIDER_WIDTH=8,
    SAMPLE_PHASE=0
)
(input clk,
    input resetb,
    input CPOL,
    input CPHA,
    input [CLK_DIVIDER_WIDTH-1:0] clk_divider,

    input go,
    input [(NUM_PORTS*DATA_WIDTH)-1:0] datai,
    output [(NUM_PORTS*DATA_WIDTH)-1:0] datao,
    output reg busy,
    output reg done,

    input [NUM_PORTS-1:0] dout,
    output [NUM_PORTS-1:0] din,
    output reg csb,
    output reg sclk
);

reg  [CLK_DIVIDER_WIDTH-1:0]  clk_count;
wire [CLK_DIVIDER_WIDTH-1:0]  next_clk_count = clk_count + 1;
wire pulse = next_clk_count == (clk_divider >> 1);
reg    state;

`ifdef verilator
    localparam LOG2_DATA_WIDTH = $clog2(DATA_WIDTH+1);
`else
    function integer log2;
        input integer value;
        integer       count;
        begin
            value = value-1;
            for (count=0; value>0; count=count+1)
                value = value>>1;
            log2=count;
        end
    endfunction
    localparam LOG2_DATA_WIDTH = log2(DATA_WIDTH+1);
`endif

reg [LOG2_DATA_WIDTH:0] shift_count;

wire start = shift_count == 0;
wire stop  = shift_count >= 2*DATA_WIDTH-1;
reg stop_s;

localparam IDLE_STATE = 0,
    RUN_STATE = 1;

sro #(.DATA_WIDTH(DATA_WIDTH)) sro[NUM_PORTS-1:0]
(.clk(clk),
    .resetb(resetb),
    .shift(pulse && !csb && (shift_count[0] == SAMPLE_PHASE) && !stop_s),
    .dout(dout),
    .datao(datao));

sri #(.DATA_WIDTH(DATA_WIDTH)) sri[NUM_PORTS-1:0]
(.clk(clk),
    .resetb(resetb),
    .datai(datai),
    .sample(go && (state == IDLE_STATE)),
    .shift(pulse && !csb && (shift_count[0] == 1) && !stop),
    .din(din));

`ifdef SYNC_RESET
    always @(posedge clk) begin
    `else      
        always @(posedge clk or negedge resetb) begin
        `endif      
        if(!resetb) begin
            clk_count <= 0;
            shift_count <= 0;
            sclk  <= 1;
            csb   <= 1;
            state <= IDLE_STATE;
            busy  <= 0;
            done  <= 0;
            stop_s <= 0;
        end else begin
            if(pulse) begin
                clk_count <= 0;
                stop_s <= stop;
            end else begin
                clk_count <= next_clk_count;
            end

            if(state == IDLE_STATE) begin
                csb  <= 1;
                shift_count <= 0;
                done <= 0;
                if(go && !busy) begin
                    state  <= RUN_STATE;
                    busy   <= 1;
                end else begin
                    busy   <= 0;
                end
            end else begin
                if(pulse) begin
                    if(stop) begin
                        if(done) begin
                            state <= IDLE_STATE;
                            done <= 0;
                            busy <= 0;
                        end else begin
                            done  <= 1;
                        end
                    end else begin
                        csb <= 0;
                        if(!csb) begin 
                            shift_count <= shift_count + 1;
                        end
                    end
                end
            end

            if(pulse) begin
                if((CPHA==1 && state==RUN_STATE && !stop) ||
                    (CPHA==0 && !csb && !stop)) begin
                    sclk <= !sclk;
                end else begin
                    sclk <= CPOL;
                end
            end
        end
    end
endmodule // spi_master

module sri
  #(parameter DATA_WIDTH=16)
  (input clk,
   input resetb,
   input [DATA_WIDTH-1:0] datai,
   input sample,
   input shift,
   output din
   );

   reg [DATA_WIDTH-1:0] sr_reg;
   assign din = sr_reg[DATA_WIDTH-1];

`ifdef SYNC_RESET
   always @(posedge clk) begin
`else
   always @(posedge clk or negedge resetb) begin
`endif
      if(!resetb) begin
         sr_reg <= 0;
      end else begin
         if(sample) begin
            sr_reg <= datai;
         end else if(shift) begin
            sr_reg <= sr_reg << 1;
         end
      end
  end
endmodule

module sro
  #(parameter DATA_WIDTH=16)
  (input clk,
   input resetb,
   input shift,
   input dout,
   output reg [DATA_WIDTH-1:0] datao
   );
   reg                     dout_s;
   
`ifdef SYNC_RESET
   always @(posedge clk) begin
`else      
   always @(posedge clk or negedge resetb) begin
`endif      
      if(!resetb) begin
         dout_s <= 0;
         datao <= 0;
      end else begin
         dout_s <= dout;
         if(shift) begin
            datao <= { datao[DATA_WIDTH-2:0], dout_s };
         end
      end
   end
endmodule
