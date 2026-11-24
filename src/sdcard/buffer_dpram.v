// SD-card sector double port RAM
// Allowing byte and word access from the 68000

module sector_dpram_16b (
    input  wire        clk,
    // SD-card 8-bit port (Port A)
    input  wire        sd_we,
    input  wire [8:0]  sd_addr,
    input  wire [7:0]  sd_din,
    output wire [7:0]  sd_dout,
    // 68000 16-bit port (Port B) with separate byte write enables
    input  wire        cpu_we_even,   // active high when writing even byte (e.g. !uds_n && wr && cs)
    input  wire        cpu_we_odd,    // active high when writing odd byte  (e.g. !lds_n && wr && cs)
    input  wire [7:0]  cpu_addr,      // 256 words = 512 bytes (reg_addr_i[7:0])
    input  wire [15:0] cpu_din,
    output wire [15:0] cpu_dout
);
    reg [7:0] sd_dout_even_q;
    reg [7:0] sd_dout_odd_q;
    reg       sd_sel_odd_q;

    reg [7:0] cpu_dout_even_q;
    reg [7:0] cpu_dout_odd_q;

  dpb_sd sd_ram_odd(
        .douta(sd_dout_odd_q), //output [7:0] douta
        .doutb(cpu_dout_odd_q), //output [7:0] doutb
        .clka(clk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(1'b0), //input reseta
        .wrea(sd_we && sd_addr[0]), //input wrea
        .clkb(clk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(1'b0), //input resetb
        .wreb(cpu_we_odd), //input wreb
        .ada(sd_addr[8:1]), //input [7:0] ada
        .dina(sd_din), //input [7:0] dina
        .adb(cpu_addr), //input [7:0] adb
        .dinb(cpu_din[7:0]) //input [7:0] dinb
    );
  
    dpb_sd sd_ram_even(
        .douta(sd_dout_even_q), //output [7:0] douta
        .doutb(cpu_dout_even_q), //output [7:0] doutb
        .clka(clk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(1'b0), //input reseta
        .wrea(sd_we && !sd_addr[0]), //input wrea
        .clkb(clk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(1'b0), //input resetb
        .wreb(cpu_we_even), //input wreb
        .ada(sd_addr[8:1]), //input [7:0] ada
        .dina(sd_din), //input [7:0] dina
        .adb(cpu_addr), //input [7:0] adb
        .dinb(cpu_din[15:8]) //input [7:0] dinb
    );

    // Port A (SD card side): separate write and read paths
    always @(posedge clk) begin
         sd_sel_odd_q   <= sd_addr[0];
    end

    assign sd_dout = sd_sel_odd_q ? sd_dout_odd_q : sd_dout_even_q;

    // Port B (CPU side): separate write and read paths
    assign cpu_dout = {cpu_dout_even_q, cpu_dout_odd_q};

endmodule