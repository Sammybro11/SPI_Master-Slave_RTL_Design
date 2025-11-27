`timescale 1ns / 1ps

module spi_slave_tb;

    parameter DATA_WIDTH = 8;

    reg                   sclk;
    reg                   cs_n;
    reg                   mosi;
    reg                   rst;
    reg                   cpol;
    reg                   cpha;
    reg [DATA_WIDTH-1:0]  tx_data;

    wire                  miso;
    wire [DATA_WIDTH-1:0] rx_data;
    wire                  rx_valid;

    // Testbench tracking variables
    reg [DATA_WIDTH-1:0] master_rx_reg;
    integer i;

    spi_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .MSB_FIRST(1)
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

    task run_spi_transaction;
        input [DATA_WIDTH-1:0] master_out_data;
        input [DATA_WIDTH-1:0] expected_slave_out;// expected MISO
        input mode_cpol;
        input mode_cpha;
        begin
            cpol = mode_cpol;
            cpha = mode_cpha;
            sclk = cpol;
            master_rx_reg = 0;
            #20;
            $display("[Time %0t] Starting Mode (CPOL=%b, CPHA=%b) | MOSI: 0x%h | Exp MISO: 0x%h",
                     $time, cpol, cpha, master_out_data, expected_slave_out);

            cs_n = 0;

            if (cpha == 0) begin
                mosi = master_out_data[DATA_WIDTH-1];
                #10;
            end else begin
                #10;
            end

            for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                if (cpha == 0) begin
                    sclk = ~sclk;
                    master_rx_reg = {master_rx_reg[DATA_WIDTH-2:0], miso};
                    #10;

                    sclk = ~sclk;
                    if (i < DATA_WIDTH-1)
                        mosi = master_out_data[DATA_WIDTH - 2 - i];
                    #10;

                end else begin
                    sclk = ~sclk;
                    mosi = master_out_data[DATA_WIDTH - 1 - i];
                    #10;

                    sclk = ~sclk;
                    master_rx_reg = {master_rx_reg[DATA_WIDTH-2:0], miso};
                    #10;
                end
            end

            #10;
            cs_n = 1;
            mosi = 0;
            sclk = cpol;
            #20;

            if (rx_valid && rx_data == master_out_data)
                $display("    [PASS] Slave RX: 0x%h", rx_data);
            else
                $display("    [FAIL] Slave RX: 0x%h (Expected: 0x%h)", rx_data, master_out_data);

            if (master_rx_reg == expected_slave_out)
                $display("    [PASS] Master RX: 0x%h", master_rx_reg);
            else
                $display("    [FAIL] Master RX: 0x%h (Expected: 0x%h)",
                    master_rx_reg, expected_slave_out);
        end
    endtask

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

        $display("");
        $display("TEST CASE 1: Standard Modes (8-bit)");
        $display("");
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
        $display("");
        $display("TEST CASE 2: Back-to-Back Transfers (Stress Test)");
        $display("");
        // Transfer 1
        tx_data = 8'h11;
        cpol=0; cpha=0; sclk=0;
        cs_n = 0;
        mosi = 1;
        #10;
        repeat(8) begin sclk=1; #10; sclk=0; #10; end
        // End Transaction 1
        cs_n = 1;
        #10;
        // Transfer 2
        tx_data = 8'hFF;
        cs_n = 0;
        #10;
        repeat(8) begin sclk=1; #10; sclk=0; #10; end
        cs_n = 1;
        #10;
        if (rx_valid) $display("    [PASS] Back-to-Back Valid Pulse Detected");
        else          $display("    [FAIL] Back-to-Back Valid Pulse Missed");


        $display("");
        $display("");
        $display("TEST CASE 3: Reset in Middle of Transaction");
        $display("");
        cpol=0; cpha=0; sclk=0;
        cs_n = 0;
        #10;
        // Clock 4 times (Halfway)
        repeat(4) begin sclk=1; #10; sclk=0; #10; end
        $display("    [INFO] Asserting Reset mid-transfer...");
        rst = 1;
        #10;
        rst = 0;
        cs_n = 1;// End transaction
        #10;
        if (rx_valid == 0) $display("    [PASS] No Valid Pulse (Correctly Aborted)");
        else               $display("    [FAIL] Valid Pulse generated despite Reset");

        $display("");
        $display("ALL TESTS COMPLETE");
        $finish;
    end

endmodule
