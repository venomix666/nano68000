module sdram_68k_interface (
    input clk_100,          // 100.7 MHz controller clock
    input clk_100p,        // phase-shifted SDRAM clock
    input reset_n,

    // 68k bus
    input [23:1] addr_i,
    input [15:0] data_i,
    output [15:0] data_o,
    output dtack_n,
    input lds_n, uds_n, rw_n, as_n,

    input ram_cs,

    // Physical SDRAM pins (Tang Nano 20K / GW2AR-18)
    output sd_clk,
    output sd_cke,
    output sd_cs_n,
    output reg sd_ras_n,
    output reg sd_cas_n,
    output reg sd_we_n,
    output reg [3:0] sd_dqm,
    output reg [10:0] sd_a,
    output reg [1:0] sd_ba,
    inout [31:0] sd_dq
);

    // SDRAM command encodings: {RAS#, CAS#, WE#}
    localparam C_NOP = 3'b111,
               C_PRE = 3'b010,
               C_REF = 3'b001,
               C_MRS = 3'b000,
               C_ACT = 3'b011,
               C_RD  = 3'b101,
               C_WR  = 3'b100;

    // Timing values are in clk_100 cycles. Confirm these against the SDRAM
    // datasheet and the actual controller/SDRAM clock phase.
    localparam T_RP       = 2;
    localparam T_RFC      = 7;
    localparam T_MRD      = 2;
    localparam T_RCD     = 2;
    localparam CAS_LATENCY = 2;
    localparam REFRESH_INTERVAL = 780; // <= 7.8125 us at 100.7 MHz

    localparam STARTUP       = 0,
               INIT_PRE       = 1,
               INIT_PRE_WAIT = 2,
               INIT_REF1     = 3,
               INIT_REF1_WAIT = 4,
               INIT_REF2     = 5,
               INIT_REF2_WAIT = 6,
               INIT_MRS     = 7,
               INIT_MRS_WAIT = 8,
               IDLE        = 9,
               ACT         = 10,
               WAIT_RCD   = 11,
               READ_WRITE = 12,
               WAIT_READ  = 13,
               WRITE_HOLD = 14,
               REFRESH   = 15,
               REFRESH_WAIT = 16;

    reg [4:0] state;
    reg [15:0] wait_cnt;
    reg [11:0] ref_timer;
    reg [31:0] data_latch;

    // One-entry cache containing one 32-bit SDRAM word.
    reg [20:0] cache_tag;
    reg cache_valid;
    wire cache_hit = cache_valid && rw_n && (addr_i[22:2] == cache_tag);

    reg [23:1] addr_i_latch;
    reg [15:0] data_i_latch;
    reg rw_n_latch;
    reg lds_n_latch;
    reg uds_n_latch;

    reg cycle_done;
    reg dtack_n_r;
    reg [1:0] init_refresh_count;

    // Keep write data on the SDRAM bus during the command edge and the
    // following hold state. Data is latched before the transaction begins.
    wire driving_bus = ((state == READ_WRITE) || (state == WRITE_HOLD))
                       && !rw_n_latch;
    assign sd_dq = driving_bus ? {data_i_latch, data_i_latch} : 32'bz;


    // Static SDRAM pins
    assign sd_clk  = clk_100p;
    assign sd_cke  = 1'b1;
    assign sd_cs_n = 1'b0;

    // 68k 16-bit read selection from the 32-bit SDRAM word.
    // addr[1] selects the halfword within the 32-bit word.
    assign data_o = (addr_i[1] == 1'b0) ? data_latch[15:0]
                                        : data_latch[31:16];
    assign dtack_n = dtack_n_r;


    always @(posedge clk_100 or negedge reset_n) begin
        if (!reset_n) begin
            state <= STARTUP;
            wait_cnt <= 16'd20000;
            {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
            sd_dqm <= 4'b1111;
            sd_a <= 11'd0;
            sd_ba <= 2'd0;
            ref_timer <= 12'd0;
            init_refresh_count <= 2'd0;
            cycle_done <= 1'b0;
            cache_tag <= 21'd0;
            cache_valid <= 1'b0;
            dtack_n_r <= 1'b1;
            addr_i_latch <= 23'd0;
            data_i_latch <= 16'd0;
            rw_n_latch <= 1'b1;
            lds_n_latch <= 1'b1;
            uds_n_latch <= 1'b1;
            data_latch <= 32'd0;
        end else begin
            // Re-arm the 68k transaction detector after the bus cycle ends.
            if (as_n || !ram_cs) begin
                cycle_done <= 1'b0;
                dtack_n_r <= 1'b1;
            end

            // Refresh interval counter runs continuously after initialization,
            // including while the controller is idle or servicing requests.
            if ((state >= IDLE) && (ref_timer < REFRESH_INTERVAL)
                && (state != REFRESH) && (state != REFRESH_WAIT)) begin
                ref_timer <= ref_timer + 1'b1;
            end


            case (state)
                STARTUP: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 1'b1;
                    else
                        state <= INIT_PRE;
                end

                // PRECHARGE ALL (A10=1), followed by tRP wait.
                INIT_PRE: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_PRE;
                    sd_a <= 11'b10000000000; // A10=1, PRECHARGE ALL
                    wait_cnt <= T_RP;
                    state <= INIT_PRE_WAIT;
                end
                INIT_PRE_WAIT: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 1'b1;
                    else
                        state <= INIT_REF1;
                end

                // Issue two separate AUTO REFRESH commands, each followed by tRFC.
                INIT_REF1: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_REF;
                    wait_cnt <= T_RFC;
                    state <= INIT_REF1_WAIT;
                end
                INIT_REF1_WAIT: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 1'b1;
                    else
                        state <= INIT_REF2;
                end
                INIT_REF2: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_REF;
                    wait_cnt <= T_RFC;
                    state <= INIT_REF2_WAIT;
                end
                INIT_REF2_WAIT: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 1'b1;
                    else
                        state <= INIT_MRS;
                end

                // Mode register: burst length 1, sequential, CAS latency 2,
                // standard operating mode. Check bit layout against the SDRAM.
                INIT_MRS: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_MRS;
                    sd_a <= 11'b000_0_010_0_000;
                    sd_ba <= 2'b00;
                    wait_cnt <= T_MRD;
                    state <= INIT_MRS_WAIT;
                end
                INIT_MRS_WAIT: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 1'b1;
                    else begin
                        ref_timer <= 12'd0;
                        cache_valid <= 1'b0;
                        state <= IDLE;
                    end
                end

                IDLE: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    sd_dqm <= 4'b0000;

                    if (ref_timer >= REFRESH_INTERVAL) begin
                        state <= REFRESH;
                    end else if (!as_n && ram_cs && !cycle_done) begin
                        if (cache_hit) begin
                            cycle_done <= 1'b1;
                            dtack_n_r <= 1'b0;
                        end else begin
                            // Snapshot the bus request so the SDRAM transaction
                            // is independent of live 68k bus signals.
                            addr_i_latch <= addr_i;
                            data_i_latch <= data_i;
                            rw_n_latch <= rw_n;
                            lds_n_latch <= lds_n;
                            uds_n_latch <= uds_n;
                            state <= ACT;
                        end
                    end
                end

                // Tang Nano 20K SDRAM: 2M x 32 = 21 word-address bits.
                // Map column = addr[9:2] (8 bits), bank = addr[11:10]
                // (2 bits), row = addr[22:12] (11 bits). Address bit 23
                // must be excluded by the external RAM chip-select decode (8 MiB).
                ACT: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_ACT;
                    sd_ba <= addr_i_latch[11:10];
                    sd_a <= addr_i_latch[22:12];
                    wait_cnt <= T_RCD;
                    state <= WAIT_RCD;
                end
                WAIT_RCD: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    // Prepare DQM before the READ/WRITE command edge.
                    if (!rw_n_latch) begin
                        if (addr_i_latch[1])
                            sd_dqm <= {uds_n_latch, lds_n_latch, 2'b11};
                        else
                            sd_dqm <= {2'b11, uds_n_latch, lds_n_latch};
                    end else begin
                        sd_dqm <= 4'b0000;
                    end

                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 1'b1;
                    else
                        state <= READ_WRITE;
                end


                READ_WRITE: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= rw_n_latch ? C_RD : C_WR;
                    // SDRAM A10=1 enables auto-precharge; column is A[7:0].
                    sd_a <= {1'b1, 2'b00, addr_i_latch[9:2]};

                    if (!rw_n_latch) begin
                        if (addr_i_latch[22:2] == cache_tag)
                            cache_valid <= 1'b0;
                        wait_cnt <= 1;
                        state <= WRITE_HOLD;
                    end else begin
                        wait_cnt <= (CAS_LATENCY - 1);
                        state <= WAIT_READ;
                    end
                end

                // Keep write data driven for one additional controller clock
                // after the WRITE command edge, then release DQ.
                WRITE_HOLD: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    cycle_done <= 1'b1;
                    dtack_n_r <= 1'b0;
                    state <= IDLE;
                end


                WAIT_READ: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    if (wait_cnt != 0) begin
                        wait_cnt <= wait_cnt - 1'b1;
                    end else begin
                        data_latch <= sd_dq;
                        cache_tag <= addr_i_latch[22:2];
                        cache_valid <= 1'b1;
                        cycle_done <= 1'b1;
                        dtack_n_r <= 1'b0;
                        state <= IDLE;
                    end
                end


                // Refresh is only initiated between CPU transactions.
                REFRESH: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_REF;
                    wait_cnt <= T_RFC;
                    ref_timer <= 12'd0;
                    state <= REFRESH_WAIT;
                end
                REFRESH_WAIT: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    if (wait_cnt != 0)
                        wait_cnt <= wait_cnt - 1'b1;
                    else
                        state <= IDLE;
                end

                default: begin
                    {sd_ras_n, sd_cas_n, sd_we_n} <= C_NOP;
                    state <= STARTUP;
                end
            endcase
        end
    end
endmodule