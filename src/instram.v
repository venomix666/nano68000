module instram(clk, addr, rwn, cs, data_i, data_o);
	input clk;
	input [14:0] addr;
    input rwn;
    input cs;
    input [15:0] data_i;
	output [15:0] data_o;
	reg [15:0] data_o; 
 
	reg [15:0] mem [32768];
    
	always @(posedge clk) data_o <= mem[addr];

 
    always @(posedge clk)
    begin
        if(!rwn && cs) mem[addr] <= data_i;
    end
endmodule