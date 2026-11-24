module addr_decoder (
    input           clk_i,
    input           rst_i,
    input   [23:1]  addr_i,
    input           rw_n,
    input           as_n_i,
    input           uds_n_i,
    input           lds_n_i,
    input   [7:0]   data_i,
    output          rom_cs_o,
    output          ram_cs_o,
    output          uart_cs_o,
    output          addr_decoder_cs_o,
    output          sdram_cs_o,
    output          sd_cs_o,
    output          dtack_n_o,
    output          berr_n_o,
    output  [7:0]   data_o
);

    reg             rom_overlay;
    reg     [7:0]   data_o_reg;
    wire            addr_decoder_cs;

    wire bus_active = ~as_n_i & (~uds_n_i | ~lds_n_i);

    // 8 KB Boot ROM: Overlayed at $000000 - $001FFF (word addresses $000000 - $000FFF)
    //                Always at   $ffe000 - $ffffff
    assign rom_cs_o = bus_active & ((rom_overlay & (addr_i[23:12] == 12'h000)) | (addr_i[23:13] ==  11'h7ff));

    // 64 KB RAM: $fe0000 - $feffff
    assign ram_cs_o = bus_active & (addr_i[23:16] == 8'hfe);

    // 8 MB SDRAM: $000000 - $7fffff - first 8k overlayed by ROM
    assign sdram_cs_o = bus_active & (addr_i[23] == 1'b0) & !(rom_overlay & (addr_i[23:12] == 12'h000));

    // UART: $800000 - $80000F
    assign uart_cs_o = bus_active & (addr_i[23:3] == 21'h100000);

    // Addr decoder $800010 - $80001F
    assign addr_decoder_cs = bus_active & (addr_i[23:3] == 21'h100002);

    // SD card $810000 - $8103FF
    assign sd_cs_o = bus_active & (addr_i[23:10] == 14'h2040);

    wire valid_addr = rom_cs_o | ram_cs_o | uart_cs_o | addr_decoder_cs | sdram_cs_o | sd_cs_o;

    reg dtack_n_r;
    reg berr_n_r;

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            dtack_n_r <= 1'b1;
            berr_n_r <= 1'b1;
        end else if (!bus_active) begin
            // Deassert DTACKn as soon as the bus cycle ends
            dtack_n_r <= 1'b1;
            berr_n_r <= 1'b1;
        end else if (valid_addr) begin
            // 1 clk_i cycle after bus_active + valid_addr is seen
            dtack_n_r <= 1'b0;
            berr_n_r <= 1'b1;
        end else begin
            dtack_n_r <= 1'b1;
            berr_n_r <= 1'b0;
        end
    end

    always @(posedge clk_i or posedge rst_i) begin
        if(rst_i) begin
            rom_overlay <= 1'b1;
        end else begin
            if(addr_decoder_cs && addr_i[3:1] == 3'd0 && !rw_n) rom_overlay <= data_i[0];
        end
    end

    always @(*) begin
        if(addr_decoder_cs && addr_i[3:1] == 3'd0) data_o_reg <= {7'd0, rom_overlay};
        else data_o_reg <= 8'd0;
    end

    assign dtack_n_o = dtack_n_r;
    assign berr_n_o = berr_n_r;
    assign addr_decoder_cs_o = addr_decoder_cs;
    assign data_o = data_o_reg;
endmodule
