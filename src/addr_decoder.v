module addr_decoder (
    input           clk_i,
    input           rst_i,
    input   [23:1]  addr_i,
    input           as_n_i,
    input           uds_n_i,
    input           lds_n_i,
    output          rom_cs_o,
    output          ram_cs_o,
    output          dtack_n_o
);

    wire bus_active = ~as_n_i & (~uds_n_i | ~lds_n_i);

    // 8 KB Boot ROM: $000000 - $001FFF (word addresses $000000 - $000FFF)
    assign rom_cs_o = bus_active & (addr_i[23:12] == 12'h000);

    // 64 KB RAM: $010000 - $01FFFF (word addresses $008000 - $00FFFF)
    assign ram_cs_o = bus_active & (addr_i[23:15] == 9'b000000010);

    wire valid_addr = rom_cs_o | ram_cs_o;

    reg dtack_n_r;

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            dtack_n_r <= 1'b1;
        end else if (!bus_active) begin
            // Deassert DTACKn as soon as the bus cycle ends
            dtack_n_r <= 1'b1;
        end else if (valid_addr) begin
            // 1 clk_i cycle after bus_active + valid_addr is seen
            dtack_n_r <= 1'b0;
        end else begin
            dtack_n_r <= 1'b1;
        end
    end

    assign dtack_n_o = dtack_n_r;

endmodule
