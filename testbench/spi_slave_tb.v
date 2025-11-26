`timescale 1ns / 1ps

module spi_slave_debug_tb;

    parameter DATA_WIDTH = 8;
    
    reg                   sclk;
    reg                   cs_n;
    reg                   mosi;
    reg                   rst;
    reg  [DATA_WIDTH-1:0] tx_data_slave; 
    reg                   cpol;
    reg                   cpha;

    wire                  miso;
    wire [DATA_WIDTH-1:0] rx_data_slave;
    wire                  rx_valid;

    integer i;
    reg [DATA_WIDTH-1:0] master_rx_data;
    reg [DATA_WIDTH-1:0] master_tx_data;

    // Instantiate DUT
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

    task send_spi_byte;
        input [DATA_WIDTH-1:0] data_to_send;
        input mode_cpol;
        input mode_cpha;
        input [DATA_WIDTH-1:0] expected_miso;
        begin
            cpol = mode_cpol;
            cpha = mode_cpha;
            master_tx_data = data_to_send;
            master_rx_data = 0;
            sclk = cpol; 
            
            #20;
            $display("------------------------------------------------------------");
            $display("[Time %0t] Test Mode (CPOL=%b, CPHA=%b)", $time, cpol, cpha);
            $display("       Master sending: 0x%h, Expecting Slave to send: 0x%h", data_to_send, expected_miso);

            cs_n = 0;
            
            // CRITICAL FIX: Ensure CS_N setup time for ALL modes.
            if (cpha == 0) begin
                // CPHA=0: Setup MOSI before first edge
                mosi = master_tx_data[DATA_WIDTH-1]; 
                #10; // t_lead
            end else begin
                // CPHA=1: Wait for CS_N to stabilize before first SCLK edge
                #10; // t_lead
            end

            for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                if (cpha == 0) begin
                    // --- MODE 0 & 2 ---
                    // EDGE 1 (Sample)
                    if (cpol == 0) sclk = 1; else sclk = 0; 
                    master_rx_data = {master_rx_data[DATA_WIDTH-2:0], miso}; // Sample MISO
                    #10; 

                    // EDGE 2 (Shift)
                    if (cpol == 0) sclk = 0; else sclk = 1; 
                    if (i < DATA_WIDTH-1) mosi = master_tx_data[DATA_WIDTH - 2 - i];
                    #10;
                end else begin
                    // --- MODE 1 & 3 ---
                    // EDGE 1 (Shift)
                    if (cpol == 0) sclk = 1; else sclk = 0; 
                    mosi = master_tx_data[DATA_WIDTH - 1 - i];
                    #10;
                    
                    // EDGE 2 (Sample)
                    if (cpol == 0) sclk = 0; else sclk = 1; 
                    master_rx_data = {master_rx_data[DATA_WIDTH-2:0], miso}; // Sample MISO
                    #10;
                end
            end

            #10;
            cs_n = 1;
            mosi = 0;
            #20;

            // CHECK SLAVE RX (MOSI Path)
            if (rx_valid && rx_data_slave == data_to_send) begin
                $display("   [PASS] Slave RX Correct: 0x%h", rx_data_slave);
            end else begin
                $display("   [FAIL] Slave RX Error:   0x%h (Exp: 0x%h)", rx_data_slave, data_to_send);
            end
            
            // CHECK MASTER RX (MISO Path)
            if (master_rx_data == expected_miso) begin
                $display("   [PASS] Master RX Correct: 0x%h", master_rx_data);
            end else begin
                $display("   [FAIL] Master RX Error:   0x%h (Exp: 0x%h)", master_rx_data, expected_miso);
            end
        end
    endtask

    initial begin
        $dumpfile("spi_debug.vcd");
        $dumpvars(0, spi_slave_debug_tb);

        rst = 1; sclk = 0; cs_n = 1; mosi = 0; cpol = 0; cpha = 0;
        tx_data_slave = 0;

        #50; rst = 0; #50;

        // Load slave with data 0xA5 for next transaction
        tx_data_slave = 8'hA5; 
        send_spi_byte(8'h3C, 0, 0, 8'hA5); // Mode 0

        #50;
        tx_data_slave = 8'hF0;
        send_spi_byte(8'h55, 0, 1, 8'hF0); // Mode 1

        #50;
        tx_data_slave = 8'h12;
        send_spi_byte(8'h99, 1, 0, 8'h12); // Mode 2

        #50;
        tx_data_slave = 8'h77;
        send_spi_byte(8'h42, 1, 1, 8'h77); // Mode 3

        #100;
        $display("------------------------------------------------------------");
        $finish;
    end

endmodule
