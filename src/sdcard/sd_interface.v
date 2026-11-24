// SD-card interface for the nano68000
//
// Registers:
// 00-03    -   SD card address (00=LSB, 03=MSB)
// 04       -   SD card busy
// 05       -   SD card start read (write any value to start)
// 06       -   SD card start write (write any value to start)
// 07       -   Not used (leftover from nano6502 code)
// 08       -   SD card status
// 09       -   SD card type
// 200-3FF  -   512 byte access to data
//

module sd_interface(
	input               clk_i,
	input               rst_n_i,
    input               wr_n,
	input   [8:0]       reg_addr_i,
    input               lds_i,
    input               uds_i,
    input   [15:0]      data_i,
    input               sd_cs,
    output  [15:0]      data_o,
    output              sdclk,
    inout               sdcmd,
    inout   [3:0]       sddat
);

parameter IDLE      = 2'd0;
parameter READING   = 2'd1;
parameter WRITING   = 2'd2;    

reg [31:0]  address;
reg         rd;
reg         wr;
reg [15:0]   data_o_reg;
wire [7:0]    sd_data_o;

reg [1:0]   state;
reg [15:0]   data_i_delay;

wire [7:0] sd_data_i;
wire rbusy;
wire rdone;
wire outen;
wire [8:0] outaddr;
wire [3:0] card_stat;
wire [1:0] card_type;
wire [15:0] buf_data_o;

always @(posedge clk_i)
    data_i_delay <= data_i;


sector_dpram_16b buffer(
    .clk(clk_i),
    .sd_we(outen),
    .sd_addr(outaddr),
    .sd_din(sd_data_o),
    .sd_dout(sd_data_i),
    .cpu_we_even(reg_addr_i[8] & !uds_i && !wr_n && sd_cs),
    .cpu_we_odd(reg_addr_i[8] & !lds_i && !wr_n && sd_cs),
    .cpu_addr(reg_addr_i[7:0]),
    .cpu_din(data_i_delay),
    .cpu_dout(buf_data_o)
);

// Asynchronous read
always @(*)
begin
    case(reg_addr_i)
        9'h000: data_o_reg = {address[15:8], address[7:0]};
        9'h001: data_o_reg = {address[31:24], address[23:16]};
        9'h002: data_o_reg = {7'd0, rbusy, 8'd0};
        9'h004: data_o_reg = {4'd0, card_stat, 6'd0, card_type};
        default:
        begin
            if(reg_addr_i[8]) data_o_reg = buf_data_o;
            else data_o_reg = 16'd0;
        end
    endcase
end

// Synchronous write
always @(posedge clk_i or negedge rst_n_i)
begin
    if(rst_n_i == 1'b0)
    begin
        address <= 32'd0;
        rd <= 1'b0;
        wr <= 1'b0;
        state <= IDLE;
    end
    else if(state == READING)
    begin
        if(!rbusy) state <= IDLE;
        rd<=1'b0;
        wr<=1'b0;
    end
    else if(state == WRITING)
    begin
        if(!rbusy) state <= IDLE;
        rd<=1'b0;
        wr<=1'b0;
    end
    else if((sd_cs) && (!wr_n))
    begin
        case(reg_addr_i)
            9'h000:  begin
                if(!uds_i) address[15:8] <= data_i[15:8];
                if(!lds_i) address[7:0] <= data_i[7:0];
            end
            9'h001:  begin
                if(!uds_i) address[31:24] <= data_i[15:8];
                if(!lds_i) address[23:16] <= data_i[7:0];
            end

            9'h002:  
            begin
                if(!rbusy && !lds_i)
                begin
                    rd <= 1'b1;
                    state <= READING;
                end
            end
            9'h003:  
            begin
                if(!rbusy && !uds_i)
                begin
                    wr <= 1'b1;
                    state <= WRITING;
                end
            end
        endcase
    end
    else
    begin
        rd <= 1'b0;
        wr <= 1'b0;
    end
end



assign data_o = data_o_reg;

sd_rw #(.CLK_DIV(3), .SIMULATE(0)) sd_rw_inst(
        .rstn(rst_n_i),
        .clk(clk_i),
        .sdclk(sdclk),
        .sdcmd(sdcmd),
        .sddat(sddat),
        .card_stat(card_stat),
        .card_type(card_type),
        .rstart(rd),
        .wstart(wr),
        .sector(address),
        .rbusy(rbusy),
        .rdone(rdone),
        .inbyte(sd_data_i),
        .outen(outen),
        .outaddr(outaddr),
        .outbyte(sd_data_o)
);

endmodule