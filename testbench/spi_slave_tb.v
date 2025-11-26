`timescale 1ns / 1ps

module spi_slave_debug_tb;

    // -------------------------------------------------------------------------
    // Parameters & Signals
    // -------------------------------------------------------------------------
    parameter DATA_WIDTH = 8;
    
    reg                   sclk;
    reg                   cs_n;
    reg                   mosi;
    reg                   rst;
    reg  [DATA_WIDTH-1:0] tx_data_slave; // Data slave wants to send
    reg                   cpol;
    reg                   cpha;

    wire                  miso;
    wire [DATA_WIDTH-1:0] rx_data_slave; // Data slave received
    wire                  rx_valid;

    // Testbench Variables
    integer i;
    reg [DATA_WIDTH-1:0] master_rx_data;
    reg [DATA_WIDTH-1:0] master_tx_data;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .MSB_FIRST(1)
    ) dut (
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .rst(rst),
        .tx_data(tx_data_slave),
        .cpol(cpol),
        .cpha(cpha),
        .miso(miso),
        .rx_data(rx_data_slave),
        .rx_valid(rx_valid)
    );

    // -------------------------------------------------------------------------
    // Tasks to Emulate SPI Master
    // -------------------------------------------------------------------------
    task send_spi_byte;
        input [DATA_WIDTH-1:0] data_to_send;
        input mode_cpol;
        input mode_cpha;
        begin
            // 1. Setup Configuration
            cpol = mode_cpol;
            cpha = mode_cpha;
            master_tx_data = data_to_send;
            master_rx_data = 0;

            // Set Idle SCLK based on CPOL
            sclk = cpol; 
            
            #20;
            $display("[Time %0t] Starting Transmit: 0x%h | Mode(CPOL=%b, CPHA=%b)", 
                     $time, data_to_send, cpol, cpha);

            // 2. Assert CS_N
            cs_n = 0;
            
            // CPHA=0: Data must be sampled on first edge, so Master drives MOSI now
            // CPHA=1: Data is driven on first edge, sampled on second.
            
            if (cpha == 0) begin
                // Setup MOSI before first edge
                mosi = master_tx_data[DATA_WIDTH-1]; 
                #10; // Setup time
            end

            // 3. Generate 8 Clock Cycles
            for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                if (cpha == 0) begin
                    // --- MODE 0 & 2 (Sample First, Shift Second) ---
                    
                    // EDGE 1: Sample
                    if (cpol == 0) sclk = 1; else sclk = 0; // Toggle to Active
                    
                    // Master Samples MISO here
                    master_rx_data = {master_rx_data[DATA_WIDTH-2:0], miso};
                    #10; 

                    // EDGE 2: Shift
                    if (cpol == 0) sclk = 0; else sclk = 1; // Toggle to Idle
                    
                    // Master Drives next MOSI
                    if (i < DATA_WIDTH-1)
                        mosi = master_tx_data[DATA_WIDTH - 2 - i];
                    #10;
                    
                end else begin
                    // --- MODE 1 & 3 (Shift First, Sample Second) ---
                    
                    // EDGE 1: Shift
                    if (cpol == 0) sclk = 1; else sclk = 0; // Toggle to Active
                    
                    // Master Drives MOSI
                    mosi = master_tx_data[DATA_WIDTH - 1 - i];
                    #10;
                    
                    // EDGE 2: Sample
                    if (cpol == 0) sclk = 0; else sclk = 1; // Toggle to Idle
                    
                    // Master Samples MISO
                    master_rx_data = {master_rx_data[DATA_WIDTH-2:0], miso};
                    #10;
                end
            end

            // 4. Deassert CS_N
            #10;
            cs_n = 1;
            mosi = 0; // Return to idle
            #20;

            // 5. Check Results
            if (rx_valid && rx_data_slave == data_to_send) begin
                $display("[PASS] Slave Received: 0x%h", rx_data_slave);
            end else begin
                $display("[FAIL] Slave Received: 0x%h (Expected: 0x%h)", rx_data_slave, data_to_send);
            end
            
            // Note: master_rx_data would be checked against tx_data_slave if we were verifying MISO
            $display("       Master Read Back: 0x%h (Expected: 0x%h)", master_rx_data, tx_data_slave);
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Stimulus
    // -------------------------------------------------------------------------
    initial begin
        // Initialize
        rst = 1;
        sclk = 0;
        cs_n = 1;
        mosi = 0;
        cpol = 0;
        cpha = 0;
        tx_data_slave = 8'hA5; // Data the slave will send back to us

        #50;
        rst = 0;
        #50;

        // Test Mode 0 (CPOL=0, CPHA=0)
        tx_data_slave = 8'hA5; // Slave loads this
        send_spi_byte(8'h3C, 0, 0); 

        // Test Mode 1 (CPOL=0, CPHA=1)
        #50;
        tx_data_slave = 8'hF0;
        send_spi_byte(8'h55, 0, 1);

        // Test Mode 2 (CPOL=1, CPHA=0)
        #50;
        tx_data_slave = 8'h12;
        send_spi_byte(8'h99, 1, 0);

        // Test Mode 3 (CPOL=1, CPHA=1)
        #50;
        tx_data_slave = 8'h77;
        send_spi_byte(8'h42, 1, 1);

        #100;
        $display("ALL TESTS COMPLETE");
        $finish;
    end

endmodule
