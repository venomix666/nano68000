module instram(clk, addr, rwn, cs, lds_i, uds_i, data_i, data_o);
	input clk;
	input [14:0] addr;
    input rwn;
    input cs;
    input lds_i;
    input uds_i;
    input [15:0] data_i;
	output [15:0] data_o;
	reg [15:0] data_o; 
 
	reg [15:0] mem [32768];
    
	always @(posedge clk) data_o <= mem[addr];

 
    always @(posedge clk)
    begin
        if(!rwn && cs) begin
            if(!uds_i)
                mem[addr][15:8] <= data_i[15:8];
            if(!lds_i)
                mem[addr][7:0] <= data_i[7:0];
        end
    end
endmodule