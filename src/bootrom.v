module bootrom(clk, addr, data);
	input clk;
	input [11:0] addr;
	output [15:0] data;
	reg [15:0] data; 
	reg [15:0] mem [4096];
	initial $readmemh("nano68000.hex", mem);
	always @(posedge clk) data <= mem[addr];
endmodule