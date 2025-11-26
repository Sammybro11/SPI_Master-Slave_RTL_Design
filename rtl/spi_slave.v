`timescale 1ns / 1ps

module spi_slave #(
    parameter DATA_WIDTH = 8,
    parameter MSB_FIRST  = 1  // 1 for MSB first, 0 for LSB first
)(
    input  wire                  sclk,      // Serial Clock from Master
    input  wire                  cs_n,      // Chip Select (Active Low)
    input  wire                  mosi,      // Master Out Slave In
    input  wire                  rst,       // System Reset
    input  wire [DATA_WIDTH-1:0] tx_data,   // Data to transmit
    input  wire                  cpol,      // Clock Polarity
    input  wire                  cpha,      // Clock Phase
    
    output reg                   miso,      // Slave Out Master In
    output reg  [DATA_WIDTH-1:0] rx_data,   // Received Data
    output reg                   rx_valid   // Pulse high when data is valid
);

    // internal registers
    reg [DATA_WIDTH-1:0] tx_reg;
    reg [DATA_WIDTH-1:0] rx_reg;
    reg [$clog2(DATA_WIDTH):0] bit_cnt; // allow counting up to DATA_WIDTH

    // -------------------------------------------------------------------------
    // Clock Edge Logic for 4 Modes
    // -------------------------------------------------------------------------
    // We normalize the clock edges based on CPOL and CPHA.
    // sample_clk: Rising edge of this signal is when we SAMPLE MOSI.
    // shift_clk:  Rising edge of this signal is when we SHIFT MISO.
    
    wire sample_clk_internal;
    wire shift_clk_internal;

    // Logic derivation:
    // Mode 0 (0,0): Sample Rising,  Shift Falling.
    // Mode 1 (0,1): Shift Rising,   Sample Falling.
    // Mode 2 (1,0): Sample Falling, Shift Rising.
    // Mode 3 (1,1): Shift Falling,  Sample Rising.
    
    // If CPOL == CPHA, we Sample on SCLK Rising.
    // If CPOL != CPHA, we Sample on SCLK Falling.
    assign sample_clk_internal = (cpol == cpha) ? sclk : ~sclk;

    // If CPOL == CPHA, we Shift on SCLK Falling.
    // If CPOL != CPHA, we Shift on SCLK Rising.
    assign shift_clk_internal  = (cpol == cpha) ? ~sclk : sclk;


    // -------------------------------------------------------------------------
    // Async Load and Setup (triggered by CS_N)
    // -------------------------------------------------------------------------
    // When CS_N goes low, we must prepare the first bit immediately if CPHA=0.
    always @(negedge cs_n or posedge rst) begin
        if (rst) begin
            bit_cnt <= 0;
            miso    <= 1'bz;
            rx_valid <= 0;
        end else begin
            // Reset for new transaction
            bit_cnt <= 0;
            tx_reg  <= tx_data;
            rx_valid <= 0;
            
            // CPHA=0 Specific: First bit must be ready BEFORE first clock edge
            if (cpha == 0) begin
                if (MSB_FIRST)
                    miso <= tx_data[DATA_WIDTH-1];
                else
                    miso <= tx_data[0];
            end 
        end
    end
    
    // -------------------------------------------------------------------------
    // MOSI Sampling Logic
    // -------------------------------------------------------------------------
    always @(posedge sample_clk_internal or posedge cs_n or posedge rst) begin
        if (rst) begin
            rx_reg <= 0;
        end else if (cs_n) begin
            // Do nothing or reset internal state if needed
        end else begin
            // Sample MOSI
            if (bit_cnt < DATA_WIDTH) begin
                if (MSB_FIRST)
                    rx_reg <= {rx_reg[DATA_WIDTH-2:0], mosi};
                else
                    rx_reg <= {mosi, rx_reg[DATA_WIDTH-1:1]};
                
                bit_cnt <= bit_cnt + 1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // MISO Shifting Logic
    // -------------------------------------------------------------------------
    always @(posedge shift_clk_internal or posedge cs_n or posedge rst) begin
        if (rst) begin
            miso <= 1'bz;
        end else if (cs_n) begin
            miso <= 1'bz; // High-Z when not selected
        end else begin
            // CPHA=0: Data is already driven for bit 0 by the async block.
            // We shift for subsequent bits.
            // CPHA=1: We shift on the first edge.
            
            if (cpha == 0) begin
                // Shift next bit (index 1 to N-1)
                // bit_cnt increments at sample edge. 
                // We need to look ahead or use the register.
                if (bit_cnt < DATA_WIDTH) begin
                     if (MSB_FIRST)
                        miso <= tx_reg[DATA_WIDTH - 2 - bit_cnt]; // Already sent MSB
                     else
                        miso <= tx_reg[bit_cnt + 1];
                end
            end else begin // CPHA = 1
                // Shift on first edge
                if (bit_cnt < DATA_WIDTH) begin
                    if (MSB_FIRST)
                        miso <= tx_reg[DATA_WIDTH - 1 - bit_cnt];
                    else
                        miso <= tx_reg[bit_cnt];
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Data Valid Generation
    // -------------------------------------------------------------------------
    always @(posedge cs_n) begin
        if (!rst && bit_cnt == DATA_WIDTH) begin
            rx_data <= rx_reg;
            rx_valid <= 1;
        end else begin
            rx_valid <= 0;
        end
    end

endmodule
