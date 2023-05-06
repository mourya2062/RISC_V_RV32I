module rv32i_regs
#(
	parameter Reg_width 			= 32		,	//specified as W in assignemnt 
	parameter No_of_Reg 			= 32		,	//specified as N in assignment 
	parameter Reg_depth_bits	= 5			//work on this to automate based on fifo_depth 
)
	(
		//system clock and synchronous reset 
		input  								clock						,
		input  								reset            		,
		
		//inputs 
		input	 [Reg_depth_bits-1:0]	rs1_reg					,
		input	 [Reg_depth_bits-1:0]	rs2_reg					,
		input  								wb_enable				,
		input	 [Reg_depth_bits-1:0]	wb_reg					,
		input  [Reg_width-1:0] 			wr_data					,
		
		//outputs 
		output [Reg_width-1:0]			rs1_data   				,
		output [Reg_width-1:0]			rs2_data   
	);
	
	reg [Reg_width-1:0] RV_Regs [0:No_of_Reg-1]				;

	//This is synchronous 
	////////////////////
	//REGS write logic//
	////////////////////
	integer i	;
	always @(posedge clock)
	begin
		if(reset == 1'b1) 
		begin
			for(i = 0;i < No_of_Reg;i = i + 1)
			begin
				RV_Regs[i]	<=	32'd0							;
			end
		end
		else if((wb_enable == 1'b1) && (wb_reg > 0)) 
		begin
			RV_Regs[wb_reg]	<=	wr_data					;
		end
	end	
	
	//This is asynchronous 
	////////////////////
	//Regs read logic//
	////////////////////	
	
	assign rs1_data	=	RV_Regs[rs1_reg]		;
	assign rs2_data	=	RV_Regs[rs2_reg]		;
	
endmodule 
	