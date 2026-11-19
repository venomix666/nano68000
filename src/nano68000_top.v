// nano68000
//
// A general purpose 68k computer designed primarily for use with
// the Tang Nano 20K board.
//
// Copyright (C) 2026 Henrik Löfgren

module nano68000_top
(
    input           clk_i,
    input           rst_i //S1
    //input           clkusb_i,
    input           uart_rx_i,
    input           uart_b_rx_i,
    output          uart_tx_o,
    output          uart_b_tx_o,
    //output          leds[5:0],
    //output          ws2812_o,
    //inout [12:0]    gpio,
    //output          sdclk,
    //output            tmds_clk_p    ,
    //output            tmds_clk_n    ,
    //output     [2:0]  tmds_data_p   ,//{r,g,b}
    //output     [2:0]  tmds_data_n   ,
    //inout           sdcmd,
    //inout [3:0]     sddat,
    //inout           usb_dp,
    //inout           usb_dm,
    // Magic SDRAM pin names
    //output O_sdram_clk,                                                        
    //output O_sdram_cke,                                                        
    //output O_sdram_cs_n,            // chip select                             
    //output O_sdram_cas_n,           // columns address select                  
    //output O_sdram_ras_n,           // row address select                      
    //output O_sdram_wen_n,           // write enable                            
    //inout [31:0] IO_sdram_dq,       // 32 bit bidirectional data bus           
    //output [10:0] O_sdram_addr,     // 11 bit multiplexed address bus          
    //output [1:0] O_sdram_ba,        // two banks                               
    //output [3:0] O_sdram_dqm        // 32/4        
);

wire rst_n;
assign rst_n = ~rst_i;

reg         phi1;
reg         phi2;
reg         rst_d;
// Generate phi1 and phi1
always @(posedge clk_i) begin
    rst_d <= rst_i;
    if(rst_i && !rst_d) begin
        phi1 <= 1'b0;
        phi2 <= 1'b1;
    end
    else begin 
        phi1 <= ~phi1;
        phi2 <= ~phi2;
    end
end

// CPU interface signal
wire            cpu_rw;
wire            cpu_as_n;
wire            cpu_lds_n;
wire            cpu_uds_n;
wire            cpu_E;
wire            vma_n;
wire            cpu_fc0;
wire            cpu_fc1;
wire            cpu_fc2;
wire            cpu_bg_n;
wire            cpu_dtack_n;
wire            cpu_reset_n_o;
reg     [15:0]  cpu_data_i;
wire    [15:0]  cpu_data_o;
wire    [23:1]  cpu_addr;


fx68k cpu (
	.clk        ( clk_i     ),
	.extReset   ( rst_i     ),
	.pwrUp      ( rst_i     ),
	.enPhi1     ( phi1       ),
	.enPhi2     ( phi2       ),

	.eRWn       ( cpu_rw    ),
	.ASn        ( cpu_as_n  ),
	.LDSn       ( cpu_lds_n ),
	.UDSn       ( cpu_uds_n ),
	.E          ( cpu_E     ),
	.VMAn       ( vma_n     ),
	.FC0        ( cpu_fc0   ),
	.FC1        ( cpu_fc1   ),
	.FC2        ( cpu_fc2   ),
	.BGn        ( cpu_bg_n  ),
	.oRESETn    ( cpu_reset_n_o ),
	.oHALTEDn   (),
	.DTACKn     ( cpu_dtack_n     ),
	.VPAn       ( 1'b1     ),
	.BERRn      ( 1'b1     ),
	.HALTn      ( 1'b1     ),
	.BRn        ( 1'b1 ),
	.BGACKn     ( 1'b1 ),
	.IPL0n      ( 1'b1     ),
	.IPL1n      ( 1'b1     ),
	.IPL2n      ( 1'b1     ),
	.iEdb       ( cpu_data_i ),
	.oEdb       ( cpu_data_o ),
	.eab        ( cpu_addr   )
);

// RAM, block RAM for now
wire            ram_cs;
wire    [15:0]  ram_data_o;

//assign ram_cs = cpu_addr[16]; // Just decode 64k-128k as RAM for now

instram main_ram(
    .clk(clk_i),
    .addr(cpu_addr[15:1]),
    .rwn(cpu_rw),
    .cs(ram_cs),
    .data_i(cpu_data_o),
    .data_o(ram_data_o)
);

// ROM
wire            rom_cs;
wire    [15:0]  rom_data_o;

//assign rom_cs = ~cpu_addr[16]; // Just decode 0-64k as ROM for now

bootrom bootrom_inst(
    .clk(clk_i),
    .addr(cpu_addr[12:1]),
    .data(rom_data_o)
);

// UART
wire    [7:0]   uart_data_o;
wire            uart_cs;
wire            uart_rx_i;
wire            uart_tx_o;
wire            uart_b_rx_i;
wire            uart_b_tx_o;
uart uart_inst(
        .clk(clk_i),
        .rst_n(rst_n),
        .data_i(cpu_data_o[15:8]),
        .uart_rx(uart_rx_i),
        .uart_b_rx(uart_b_rx_i),
        .uart_cs(uart_cs),
        .R_W_n(wr_n),
        .reg_addr(cpu_addr[9:1]),
        .data_o(uart_data_o),
        .uart_a_rx_irq_n_o(),
        .uart_b_rx_irq_n_o(),
        .uart_tx(uart_tx_o),
        .uart_b_tx(uart_b_tx_o)
);

// Address decoder
addr_decoder addr_decoder(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .addr_i(cpu_addr),
    .as_n_i(cpu_as_n),
    .uds_n_i(cpu_uds_n),
    .lds_n_i(cpu_lds_n),
    .rom_cs_o(rom_cs),
    .ram_cs_o(ram_cs),
    .uart_cs_o(uart_cs),
    .dtack_n_o(cpu_dtack_n)
);

// CPU input data mux
always @(*) begin
    if(rom_cs == 1'b1) cpu_data_i = rom_data_o;
    else if(ram_cs == 1'b1) cpu_data_i = ram_data_o;
    else if(uart_cs == 1'b1) cpu_data_i = {uart_data_o, 8'h00};
    else cpu_data_i = cpu_data_o;
end

endmodule
