module rv32_wb_top
(
	// system clock and synchronous reset
	input 				clk								,
	input 				reset								,
	// from mem
	input 	[31:0] 	pc_in								,
	input 	[31:0] 	iw_in								,
	input 	[31:0] 	alu_result_in					,
	input 	[4:0] 	wb_reg_in						,
	input 				wb_enable_in					,
	input		[31:0]	memif_rdata						,
	input		[31:0]	io_rdata							,
	input 				mem_io_oper_re					,
	// register interface
	output 				regif_wb_enable				,
	output 	[4:0] 	regif_wb_reg					,
	output 	[31:0] 	regif_wb_data					,
	
	// Load Hazard detection to EX stage
	output 				df_wb_from_mem_wb				,
	
	//to id stage for data hazard detection 
	output				df_wb_enable					,
	output	[4:0]		df_wb_reg						,	//This will be connected to EX stage also for load hazard 
	output 	[31:0]	df_wb_data							//This will be connected to EX stage also for load hazard 
);

	wire				signed_0_unsigned_1			;
	wire 	[1:0]		width								; 
	wire	[1:0]		byte_addr						;
	reg 	[31:0] 	alu_result_out_comb			;

	assign width					=	iw_in[13:12]														;//funct3[1:0]
	assign signed_0_unsigned_1	=	iw_in[14]															;//funct3[2]
	assign byte_addr				=	alu_result_in[1:0]												;//Last two bits of memory address
	
	
		
	//comb block to differentiate between the actual ALU data and memory data 
	always @(*)
	begin
		if(mem_io_oper_re)
		begin
			if(alu_result_in[31])
				alu_result_out_comb	<=	Load_rd_data(io_rdata,width,byte_addr,signed_0_unsigned_1)	;
			else
				alu_result_out_comb	<=	Load_rd_data(memif_rdata,width,byte_addr,signed_0_unsigned_1)	;
		end
		else
			alu_result_out_comb	<=	alu_result_in	;
	end
	
	
	assign regif_wb_enable	=	wb_enable_in			;
	assign regif_wb_reg		=	wb_reg_in				;
	assign regif_wb_data		=	alu_result_out_comb	;//alu_result_in		;
	
	assign df_wb_enable		=	wb_enable_in			;
	assign df_wb_reg			=	wb_reg_in				;	
	assign df_wb_data			=	alu_result_out_comb	;//alu_result_in		;
	
	assign df_wb_from_mem_wb	=	mem_io_oper_re		;
			
	/////////////////////////////////////////////////////////
	//////Functions 
	/////////////////////////////////////////////////////////	
	
	function [31:0] 	Load_rd_data			;//function name 
		input [31:0] 	d_rdata					;//memory data 
		input [1:0]		width 					;//differentionation b/w byte ,half word and word 
		input [1:0]		byte_addr 				;//indicates which bytes to be loaded during the LB,LH,LBU,LHU
		input 			signed_0_unsigned_1	;//signed or unsigned load 
		
		parameter BYTE 	= 2'd0	;
		parameter H_WORD 	= 2'd1	;
		parameter WORD 	= 2'd2	;
	begin
		case(width)
			BYTE:
					case(byte_addr)
							2'd0:
							begin
								if(signed_0_unsigned_1)
									Load_rd_data	= {{24{1'b0}},d_rdata[7:0]}	;
								else
									Load_rd_data	= {{24{d_rdata[7]}},d_rdata[7:0]}	;
							end 
							2'd1:
							begin
								if(signed_0_unsigned_1)
									Load_rd_data	= {{24{1'b0}},d_rdata[15:8]}	;
								else
									Load_rd_data	= {{24{d_rdata[15]}},d_rdata[15:8]}	;
							end 
							2'd2:
							begin
								if(signed_0_unsigned_1)
									Load_rd_data	= {{24{1'b0}},d_rdata[23:16]}	;
								else
									Load_rd_data	= {{24{d_rdata[23]}},d_rdata[23:16]}	;
							end 
							2'd3:
							begin
								if(signed_0_unsigned_1)
									Load_rd_data	= {{24{1'b0}},d_rdata[31:24]}	;
								else
									Load_rd_data	= {{24{d_rdata[31]}},d_rdata[31:24]}	;
							end 
					endcase 
					
			H_WORD:
					case(byte_addr)
							2'd0:
							begin
								if(signed_0_unsigned_1)
									Load_rd_data	= {{16{1'b0}},d_rdata[15:0]}	;
								else
									Load_rd_data	= {{16{d_rdata[15]}},d_rdata[15:0]}	;
							end 
							2'd1:
							begin
								if(signed_0_unsigned_1)
									Load_rd_data	= {{16{1'b0}},d_rdata[23:8]}	;
								else
									Load_rd_data	= {{16{d_rdata[23]}},d_rdata[23:8]}	;
							end 
							2'd2:
							begin
								if(signed_0_unsigned_1)
									Load_rd_data	= {{16{1'b0}},d_rdata[31:16]}	;
								else
									Load_rd_data	= {{16{d_rdata[31]}},d_rdata[31:16]}	;
							end 
					endcase 
					
			WORD	:
					case(byte_addr)
							2'd0:Load_rd_data	= d_rdata	;//for WORD 
					endcase 
		endcase
	end 
	endfunction

endmodule 