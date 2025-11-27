`timescale 1ns / 1ps

module spi_slave #(
    parameter DATA_WIDTH = 8,
    parameter MSB_FIRST  = 1
)(
    input  wire                  sclk,
    input  wire                  cs_n,
    input  wire                  mosi,
    input  wire                  rst,
    input  wire [DATA_WIDTH-1:0] tx_data,
    input  wire                  cpol,
    input  wire                  cpha,

    output reg                   miso,
    output reg  [DATA_WIDTH-1:0] rx_data,
    output reg                   rx_valid
);

    reg [DATA_WIDTH-1:0] tx_reg;
    reg [DATA_WIDTH-1:0] rx_reg;
    reg [$clog2(DATA_WIDTH):0] bit_cnt; // bit_cnt is number of bit already sampled

    wire sample_clk_internal;
    wire shift_clk_internal;

    // Mode 0 (0,0): Sample Rising,  Shift Falling
    // Mode 1 (0,1): Shift Rising,   Sample Falling
    // Mode 2 (1,0): Sample Falling, Shift Rising
    // Mode 3 (1,1): Shift Falling,  Sample Rising

    assign sample_clk_internal = (cpol == cpha) ? sclk : ~sclk;
    assign shift_clk_internal  = (cpol == cpha) ? ~sclk : sclk;

    always @(negedge cs_n or posedge rst) begin
        if (rst) begin
            bit_cnt <= 0;
            miso    <= 1'bz;
            rx_valid <= 0;
            rx_reg  <= 0;
        end else begin
            bit_cnt <= 0;
            tx_reg  <= tx_data; // Load data to send
            rx_valid <= 0;

            if (cpha == 0) begin
                if (MSB_FIRST)
                    miso <= tx_data[DATA_WIDTH-1];
                else
                    miso <= tx_data[0];
            end
        end
    end

    always @(posedge sample_clk_internal or posedge cs_n or posedge rst) begin
        if (rst) begin
            rx_reg <= 0;
        end else if (cs_n) begin
            // Reset logic handled in negedge cs_n block
        end else begin
            if (bit_cnt < DATA_WIDTH) begin
                if (MSB_FIRST)
                    rx_reg <= {rx_reg[DATA_WIDTH-2:0], mosi};
                else
                    rx_reg <= {mosi, rx_reg[DATA_WIDTH-1:1]};

                bit_cnt <= bit_cnt + 1;
            end
        end
    end

    always @(posedge shift_clk_internal or posedge cs_n or posedge rst) begin
        if (rst) begin
            miso <= 1'bz;
        end else if (cs_n) begin
            miso <= 1'bz;
        end else begin
            // In CPHA=0: This edge happens AFTER sample. bit_cnt is 1. We want Bit 6. (7-1=6)
            // In CPHA=1: This edge happens BEFORE sample. bit_cnt is 0. We want Bit 7. (7-0=7)
            if (bit_cnt < DATA_WIDTH) begin
                if (MSB_FIRST)
                    miso <= tx_reg[DATA_WIDTH - 1 - bit_cnt];
                else
                    miso <= tx_reg[bit_cnt];
            end
        end
    end

    always @(posedge cs_n) begin
        if (!rst && bit_cnt == DATA_WIDTH) begin
            rx_data <= rx_reg;
            rx_valid <= 1;
        end else begin
            rx_valid <= 0;
        end
    end

endmodule
