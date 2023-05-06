module sync_dual_port_ram
#(parameter ADDR_WIDTH=15)
(
	// Clock
	input 						clk		,
	// Instruction port (RO)
	input [ADDR_WIDTH-1:0] 	i_addr	,
	output reg 	[31:0] 		i_rdata	,
	// Data port (RW)
	input [ADDR_WIDTH-1:0] 	d_addr	,
	output reg 	[31:0] 		d_rdata	,
	input 						d_we		,
	input 		[3:0] 		d_be		,
	input 		[31:0] 		d_wdata
);

// NOTE: The Intel hex file is used to initialize the M9K ram modules
//Quartis interprets the file data as big-endian
//RISC-V is a little-endian machine
//This module converts the endianess during reads and writes
//Advice for this semester: Just use this code as is

// Multi-dimensional packed array initialized by bit stream from "ram.hex"
(* preserve *)(* ram_init_file = "Lab8_test1_word.hex" *) logic [3:0][7:0] ram[(2**ADDR_WIDTH)-1:0];

// Instruction fetch
always @ (posedge clk)
begin
	{i_rdata[7:0],i_rdata[15:8],i_rdata[23:16],i_rdata[31:24]} <= ram[i_addr];
end

// Data r/w
always @ (posedge clk)
begin
	if (d_we)
	begin
		if (d_be[0]) 
			ram[d_addr][3] <= d_wdata[7:0]		;
		if (d_be[1]) 
			ram[d_addr][2] <= d_wdata[15:8]		;
		if (d_be[2]) 
			ram[d_addr][1] <= d_wdata[23:16]		;
		if (d_be[3]) 
			ram[d_addr][0] <= d_wdata[31:24]		;
	end
	
	{d_rdata[7:0],d_rdata[15:8],d_rdata[23:16],d_rdata[31:24]} <= ram[d_addr];
	
end

endmodule 