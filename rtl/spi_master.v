module spi_master
    (input clk);

endmodule

module divider
    (input clk,
    input resetn, // Active is Low
    input [7:0] clk_divider,
    output pulse);

    reg [7:0]counter;
    wire [7:0]next_counter = counter + 8'd1;
    assign pulse = (next_counter == (clk_divider >> 1));

    always @(posedge clk or negedge resetn) begin
        if(!resetn) begin // When low activate reset
            counter <= 0;
        end else begin
            if(pulse) begin
                counter <= 0;
            end else begin
                counter <= next_counter;
            end
        end
    end
endmodule
