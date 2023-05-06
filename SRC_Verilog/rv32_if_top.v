module rv32_if_top
#(
	parameter	PC_RESET = 32'b0
)
(
	// system clock and synchronous reset
	input 					clk							,
	input 					reset							,
	// memory interface
	output 		[31:0]	memif_addr					,
	input 		[31:0] 	memif_data					,
	// to id
	output reg 	[31:0] 	pc_out						,
	output   	[31:0] 	iw_out						,
	//from id 
	input 					halt_flag					,
	input 					jump_enable_in				,
	input 		[31:0] 	jump_addr_in				,
	
	input						lw_stall_flag_from_ID	,
	input			[31:0]	lw_stall_pc_from_ID		,
	input			[31:0]	lw_stall_iw_from_ID				
);

reg [31:0]	PC	;

always @(posedge clk)
begin
	if(reset)
		PC <= PC_RESET						;
	else if(halt_flag)
		PC	<=	PC								;
	else if(jump_enable_in)
		PC	<=	jump_addr_in				;
	else if(lw_stall_flag_from_ID)
		PC	<=	PC								;
	else
		PC	<=	PC + 4						;
end 

assign memif_addr	=	PC					;
	
//registering for pc_out to match the latency of iw_out from memory
always @(posedge clk)
begin
		pc_out	<=	PC	;
end 

//assign iw_out	=	(jump_enable_in == 1'b1)? 32'h00000013: memif_data	;	//This memif_data is already getting registerd in the ram file 
assign iw_out	=	memif_data	;	//This memif_data is already getting registerd in the ram file 

//always @(*)
//begin
//	if(lw_stall_flag_from_ID)
//		iw_out	=	lw_stall_iw_from_ID	;
//	else
//		iw_out	=	memif_data				;
//end 

endmodule 