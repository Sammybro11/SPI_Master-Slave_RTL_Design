`timescale 1ns / 1ps

module spi_slave_tb;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter DATA_WIDTH = 8;

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    reg                   sclk;
    reg                   cs_n;
    reg                   mosi;
    reg                   rst;
    reg                   cpol;
    reg                   cpha;
    reg [DATA_WIDTH-1:0]  tx_data; // Data the slave *wants* to send
    
    wire                  miso;
    wire [DATA_WIDTH-1:0] rx_data; // Data the slave *received*
    wire                  rx_valid;

    // Testbench tracking variables
    reg [DATA_WIDTH-1:0] master_rx_reg; // Emulate master receiving MISO
    integer i;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .MSB_FIRST(1) // Testing MSB First
    ) dut (
        .sclk(sclk),
        .cs_n(cs_n),
        .mosi(mosi),
        .rst(rst),
        .cpol(cpol),
        .cpha(cpha),
        .tx_data(tx_data),
        .miso(miso),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    // -------------------------------------------------------------------------
    // Task: SPI Transaction (Virtual Master)
    // -------------------------------------------------------------------------
    task run_spi_transaction;
        input [DATA_WIDTH-1:0] master_out_data;
        input [DATA_WIDTH-1:0] expected_slave_out; // What we expect MISO to be
        input mode_cpol;
        input mode_cpha;
        begin
            // 1. Setup Phase
            cpol = mode_cpol;
            cpha = mode_cpha;
            sclk = cpol; // Idle state of clock
            master_rx_reg = 0;
            
            #20; // Guard time
            $display("[Time %0t] Starting Mode (CPOL=%b, CPHA=%b) | MOSI: 0x%h | Exp MISO: 0x%h", 
                     $time, cpol, cpha, master_out_data, expected_slave_out);

            // 2. Assert Chip Select
            cs_n = 0;

            // CRITICAL TIMING: Setup for CPHA=0 vs CPHA=1
            if (cpha == 0) begin
                // Mode 0/2: Data driven on CS_N edge (or before first clock)
                mosi = master_out_data[DATA_WIDTH-1]; 
                #10; // Setup time before first clock
            end else begin
                // Mode 1/3: Data driven on first clock edge
                #10; // Wait for CS to settle
            end

            // 3. Clocking Loop (8 cycles)
            for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                
                if (cpha == 0) begin 
                    // --- CPHA=0 (Sample First, Shift Second) ---
                    
                    // A. Sample Edge (Rising if CPOL=0)
                    sclk = ~sclk; 
                    // Master reads MISO here
                    master_rx_reg = {master_rx_reg[DATA_WIDTH-2:0], miso};
                    #10;

                    // B. Shift Edge (Falling if CPOL=0)
                    sclk = ~sclk;
                    // Master drives next MOSI here
                    if (i < DATA_WIDTH-1) 
                        mosi = master_out_data[DATA_WIDTH - 2 - i];
                    #10;

                end else begin 
                    // --- CPHA=1 (Shift First, Sample Second) ---
                    
                    // A. Shift Edge
                    sclk = ~sclk;
                    // Master drives MOSI
                    mosi = master_out_data[DATA_WIDTH - 1 - i];
                    #10;

                    // B. Sample Edge
                    sclk = ~sclk;
                    // Master samples MISO
                    master_rx_reg = {master_rx_reg[DATA_WIDTH-2:0], miso};
                    #10;
                end
            end

            // 4. Cleanup
            #10;
            cs_n = 1; // Deassert CS
            mosi = 0;
            sclk = cpol; // Return to idle
            #20;

            // 5. Verify Results
            
            // Check 1: Did Slave receive correct MOSI data?
            if (rx_valid && rx_data == master_out_data) 
                $display("    [PASS] Slave RX: 0x%h", rx_data);
            else
                $display("    [FAIL] Slave RX: 0x%h (Expected: 0x%h)", rx_data, master_out_data);

            // Check 2: Did Master receive correct MISO data?
            if (master_rx_reg == expected_slave_out) 
                $display("    [PASS] Master RX: 0x%h", master_rx_reg);
            else
                $display("    [FAIL] Master RX: 0x%h (Expected: 0x%h)", master_rx_reg, expected_slave_out);
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("spi_slave_test.vcd");
        $dumpvars(0, spi_slave_tb);

        // Initialize
        rst = 1;
        sclk = 0;
        cs_n = 1;
        mosi = 0;
        cpol = 0;
        cpha = 0;
        tx_data = 0;

        #20;
        rst = 0;
        #20;

        $display("==================================================");
        $display("TEST CASE 1: Standard Modes (8-bit)");
        $display("==================================================");
        
        // Mode 0: Master sends 0xA1, Slave sends 0x55
        tx_data = 8'h55;
        run_spi_transaction(8'hA1, 8'h55, 0, 0);

        // Mode 1: Master sends 0xB2, Slave sends 0xAA
        tx_data = 8'hAA;
        run_spi_transaction(8'hB2, 8'hAA, 0, 1);

        // Mode 2: Master sends 0xC3, Slave sends 0x33
        tx_data = 8'h33;
        run_spi_transaction(8'hC3, 8'h33, 1, 0);

        // Mode 3: Master sends 0xD4, Slave sends 0xCC
        tx_data = 8'hCC;
        run_spi_transaction(8'hD4, 8'hCC, 1, 1);


        $display("");
        $display("==================================================");
        $display("TEST CASE 2: Back-to-Back Transfers (Stress Test)");
        $display("==================================================");
        
        // Transfer 1
        tx_data = 8'h11;
        // Manual Start of Transaction 1
        cpol=0; cpha=0; sclk=0;
        cs_n = 0; 
        mosi = 1; // dummy mosi setup
        #10; // FIX: Added setup time for CPHA=0
        
        // Clock 8 times
        repeat(8) begin sclk=1; #10; sclk=0; #10; end
        
        // End Transaction 1
        cs_n = 1;
        #10; // Very short gap!
        
        // Transfer 2 (Immediate)
        tx_data = 8'hFF;
        cs_n = 0;
        #10; // FIX: Added setup time for CPHA=0 (Critical for back-to-back)
        repeat(8) begin sclk=1; #10; sclk=0; #10; end
        cs_n = 1;
        
        // Check if last valid was correct (Manual check)
        #10;
        if (rx_valid) $display("    [PASS] Back-to-Back Valid Pulse Detected");
        else          $display("    [FAIL] Back-to-Back Valid Pulse Missed");


        $display("");
        $display("==================================================");
        $display("TEST CASE 3: Reset in Middle of Transaction");
        $display("==================================================");
        
        cpol=0; cpha=0; sclk=0;
        cs_n = 0;
        #10; // FIX: Added setup time here as well for consistency
        
        // Clock 4 times (Halfway)
        repeat(4) begin sclk=1; #10; sclk=0; #10; end
        
        $display("    [INFO] Asserting Reset mid-transfer...");
        rst = 1;
        #10;
        rst = 0;
        cs_n = 1; // End transaction
        
        #10;
        if (rx_valid == 0) $display("    [PASS] No Valid Pulse (Correctly Aborted)");
        else               $display("    [FAIL] Valid Pulse generated despite Reset");

        $display("");
        $display("ALL TESTS COMPLETE");
        $finish;
    end

endmodule
