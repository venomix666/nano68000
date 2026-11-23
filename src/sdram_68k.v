// Tang Nano 20K SDRAM interface for a 68000.
// Converted from the working Z80 controller

module sdram_68k_interface (
    input clk_100,
    input clk_100p,
    input reset_n,

    // m68k bus
    input  [23:1] addr_i,
    input  [15:0] data_i,
    output [15:0] data_o,
    output dtack_n,
    input lds_n,
    input uds_n,
    input rw_n,
    input as_n,
    input ram_cs,

    // Physical SDRAM pins (Tang Nano 20K / GW2AR-18)
    output        sd_clk,
    output        sd_cke,
    output        sd_cs_n,
    output reg     sd_ras_n,
    output reg     sd_cas_n,
    output reg     sd_we_n,
    output reg [3:0] sd_dqm,
    output reg [10:0] sd_a,
    output reg [1:0]  sd_ba,
    inout [31:0] sd_dq
);

    localparam C_NOP = 3'b111,
               C_PRE = 3'b010,
               C_REF = 3'b001,
               C_MRS = 3'b000,
               C_ACT = 3'b011,
               C_RD  = 3'b101,
               C_WR  = 3'b100;

    localparam STARTUP      = 0,
               INIT_PRE      = 1,
               INIT_REF      = 2,
               INIT_MRS      = 3,
               IDLE         = 4,
               ACT          = 5,
               READ_WRITE   = 6,
               WAIT_CL      = 7,
               REFRESH      = 8,
               REFRESH_WAIT = 9;

    reg [3:0]  state;
    reg [15:0] wait_cnt;
    reg [11:0] ref_timer;

    reg [31:0] data_latch;

    // Cache one 32-bit SDRAM word.
    reg [20:0] cache_tag;
    reg cache_valid;

    reg [22:1] addr_i_latch;
    reg [15:0] data_i_latch;
    reg lds_n_latch;
    reg uds_n_latch;
    reg rw_n_latch;

    reg cycle_done;
    reg dtack_n_r;

    wire cache_hit = cache_valid && rw_n &&
                     (addr_i[22:2] == cache_tag);

    wire driving_bus = (state == READ_WRITE) && !rw_n_latch;

    // Replicate the 16-bit 68000 write bus data to both SDRAM halves.
    // DQM masks the unused half and/or byte lanes.
    assign sd_dq = driving_bus ? {data_i_latch, data_i_latch} : 32'bz;

    assign sd_clk  = clk_100;
    assign sd_cke  = 1'b1;
    assign sd_cs_n = 1'b0;
    assign dtack_n = dtack_n_r;

    // addr_i[1] selects one of the two 16-bit halves of the 32-bit word.
    assign data_o = addr_i[1] ? data_latch[31:16] : data_latch[15:0];

    always @(posedge clk_100 or negedge reset_n) begin
        if (!reset_n) begin
            state        <= STARTUP;
            wait_cnt     <= 16'd20000;
            ref_timer    <= 12'd0;
            dtack_n_r    <= 1'b1;
            cycle_done   <= 1'b0;
            cache_tag    <= 21'd0;
            cache_valid  <= 1'b0;
            {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
            sd_dqm       <= 4'b1111;
            sd_a          <= 11'd0;
            sd_ba         <= 2'd0;
            data_latch    <= 32'd0;
            addr_i_latch  <= 22'd0;
            data_i_latch  <= 16'd0;
            lds_n_latch   <= 1'b1;
            uds_n_latch   <= 1'b1;
            rw_n_latch    <= 1'b1;
        end else begin
            // A 68000 bus cycle is held until AS is released.
            if (as_n || !ram_cs) begin
                cycle_done <= 1'b0;
                dtack_n_r  <= 1'b1;
            end

            if (state > IDLE)
                if (ref_timer < 12'd1560)
                    ref_timer <= ref_timer + 1'b1;

            case (state)
                STARTUP: begin
                    if (wait_cnt > 0)
                        wait_cnt <= wait_cnt - 1'b1;
                    else
                        state <= INIT_PRE;
                end

                INIT_PRE: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_PRE;
                    sd_a[10] <= 1'b1;
                    state <= INIT_REF;
                    wait_cnt <= 16'd8;
                end

                INIT_REF: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_REF;
                    if (wait_cnt > 0)
                        wait_cnt <= wait_cnt - 1'b1;
                    else
                        state <= INIT_MRS;
                end

                INIT_MRS: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_MRS;
                    sd_a <= 11'b000_0_010_0_000;
                    state <= IDLE;
                end

                IDLE: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;

                    if (ref_timer >= 12'd1560) begin
                        state <= REFRESH;
                    end else if (!as_n && ram_cs && !cycle_done) begin
                        if (rw_n && cache_hit) begin
                            cycle_done <= 1'b1;
                            dtack_n_r <= 1'b0;
                        end else begin
                            addr_i_latch <= addr_i[22:1];
                            data_i_latch <= data_i;
                            lds_n_latch  <= lds_n;
                            uds_n_latch  <= uds_n;
                            rw_n_latch   <= rw_n;
                            state <= ACT;
                        end
                    end
                end

                ACT: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_ACT;

                    // Row [22:12], bank [11:10], column [9:2].
                    sd_ba <= addr_i_latch[11:10];
                    sd_a  <= addr_i_latch[22:12];
                    state <= READ_WRITE;
                end

                READ_WRITE: begin
                    {sd_ras_n, sd_cas_n, sd_we_n}
                        <= rw_n_latch ? C_RD : C_WR;

                    // A10=1 selects auto-precharge.
                    sd_a <= {1'b1, 2'b00, addr_i_latch[9:2]};

                    if (!rw_n_latch) begin
                        if (addr_i_latch[22:2] == cache_tag)
                            cache_valid <= 1'b0;

                        // Active-high DQM: low-half DQM[1:0] or
                        // high-half DQM[3:2] mask byte lanes.
                        if (!addr_i_latch[1])
                            sd_dqm <= {2'b11, uds_n_latch, lds_n_latch};
                        else
                            sd_dqm <= {uds_n_latch, lds_n_latch, 2'b11};
                    end else begin
                        sd_dqm <= 4'b0000;
                    end

                    wait_cnt <= 16'd2;
                    state <= WAIT_CL;
                end

                WAIT_CL: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;

                    if (wait_cnt > 0) begin
                        wait_cnt <= wait_cnt - 1'b1;
                    end else begin
                        if (rw_n_latch) begin
                            data_latch <= sd_dq;
                            cache_tag   <= addr_i_latch[22:2];
                            cache_valid <= 1'b1;
                        end

                        cycle_done <= 1'b1;
                        dtack_n_r  <= 1'b0;
                        state <= IDLE;
                    end
                end

                REFRESH: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_REF;
                    wait_cnt <= 16'd4;
                    ref_timer <= 12'd0;
                    state <= REFRESH_WAIT;
                end

                REFRESH_WAIT: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;

                    if (wait_cnt > 0)
                        wait_cnt <= wait_cnt - 1'b1;
                    else
                        state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule