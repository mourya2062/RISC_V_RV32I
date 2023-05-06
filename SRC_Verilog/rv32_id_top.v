module rv32_id_top
(
	// system clock and synchronous reset
	input 					clk								,
	input 					reset								,
	// from if
	input 		[31:0] 	pc_from_IF						,
	input			[31:0] 	iw_from_IF						,
	// register interface
	output 		[4:0] 	regif_rs1_reg					,
	output 		[4:0] 	regif_rs2_reg					,
	input 		[31:0] 	regif_rs1_data					,
	input 		[31:0] 	regif_rs2_data					,
	// to ex
	output reg 	[31:0] 	rs1_data_out					,
	output reg 	[31:0] 	rs2_data_out					,
	output reg 	[31:0] 	pc_out							,
	output reg 	[31:0] 	iw_out							,
	output reg 	[4:0] 	wb_reg_out						,
	output reg 				wb_enable_out					,
	output reg  [31:0]	signex_or_up_immediate_out	,
	//to if 
	output reg 				halt_flag						,
	output 					jump_enable_out				,
	output 		[31:0] 	jump_addr_out					,
	//data hazard related signals 
	//from ex
	input						df_ex_enable					,
	input			[4:0]		df_ex_reg						,
	input 		[31:0]	df_ex_data						,
	//from mem
	input						df_mem_enable					,
	input			[4:0]		df_mem_reg						,
	input 		[31:0]	df_mem_data						,
	//from wb
	input						df_wb_enable					,
	input			[4:0]		df_wb_reg						,
	input 		[31:0]	df_wb_data						,
	
	//lw_stall related signals to ID 
	output					lw_stall_flag_to_IF			,
	output		[31:0]	lw_stall_pc_to_IF				,
	output		[31:0]	lw_stall_iw_to_IF				,
	//load Hazard related signals 
	//from ex  
	input 					df_wb_from_mem_ex				,
	//from mem 
	input 					df_wb_from_mem_mem 			,
	
	//debug signals 
	output		[31:0]	iw_debug_ID						,
	output		[31:0]	pc_debug_ID						
	
);

	//These are the type of instructions which requires data to be written to the destination register 
	parameter	R_type			=	7'b0110011		;
	parameter	I_type_LOAD		=	7'b0000011		;	
	parameter	I_type_ALU		=	7'b0010011		;//same as parameter	I_type_OPER	in EX module ,felt ALU is sophisticated name 
		//Test These instructions in the future labs 
	parameter	U_type_LUI		=	7'b0110111		;
	parameter	U_type_AUIPC	=	7'b0010111		;
	
	//The below mentioned type of instructions are the one which require address jumping 
		//J-type
	parameter	J_type		=	7'b1101111	;	
		//JUMP AND LINK	
	parameter	I_type_JALR	=	7'b1100111	;
		//B-type
	parameter	B_type		=	7'b1100011	;	
	parameter 	BEQ			=	3'b000		;
	parameter	BNE			=	3'b001		;
	parameter	BLT			=	3'b100		;	
	parameter 	BGE			=	3'b101		;
	parameter	BLTU			=	3'b110		;
	parameter	BGEU			=	3'b111		;
	
	parameter	S_type		=	7'b0100011	;	
	parameter   E_BREAK		=	32'h00100073;
	
	wire 	[6:0] 	opcode							;
	wire	[2:0]		funct3							;
	wire signed	[31:0]	rs1_data_in_temp				;
	wire signed	[31:0]	rs2_data_in_temp				;
	reg	[31:0]	rs1_data_out_buff				;
	reg	[31:0]	rs2_data_out_buff				;
	reg	[31:0]	signex_or_up_immediate		;
	reg				jump_enable						;
	reg				jump_enable_del				;
	wire				jump_enable_rsg				;
	reg				jump_enable_rsg_del			;
	reg	[31:0]	jump_addr						;
	reg				lw_stall_op						;
	reg				lw_stall_br						;
	wire				lw_stall							;
	reg				lw_stall_del					;
	
	reg	[31:0]	iw_in								;
	reg	[31:0]	pc_in								;
	reg	[31:0]	iw_stall							;
	reg	[31:0]	pc_stall							;
 	
	always @(*)
	begin
		if(lw_stall_del)
		begin
			iw_in	=	iw_stall	;
			pc_in	=	pc_stall	;
		end 
		else
		begin
			iw_in	=	iw_from_IF	;
			pc_in	=	pc_from_IF	;
		end 
	end 
	
	assign 	opcode 			= 	iw_in[6:0]		;
	assign 	funct3			=	iw_in[14:12]	;
	assign 	regif_rs1_reg	=	iw_in[19:15]	;
	assign 	regif_rs2_reg	=	iw_in[24:20]	;
	
	
	//load data hazard detection 
	always @(*)
	begin
		if(df_wb_from_mem_ex)
		begin
			if(((regif_rs1_reg == df_ex_reg) && (regif_rs1_reg != 0)) || ((regif_rs2_reg == df_ex_reg) && (regif_rs2_reg != 0)))
				lw_stall_op	=	1'b1	;
			else
				lw_stall_op	=	1'b0	;
		end
		else
			lw_stall_op = 1'b0	;
	end 

	//load data hazard detection (Branch)
	always @(*)
	begin
		if((df_wb_from_mem_mem == 1'b1)&&(opcode == B_type))
		begin
			if(((regif_rs1_reg == df_mem_reg) && (regif_rs1_reg != 0)) || ((regif_rs2_reg == df_mem_reg) && (regif_rs2_reg != 0)))
				lw_stall_br	=	1'b1	;
			else
				lw_stall_br	=	1'b0	;
		end 
		else
			lw_stall_br = 1'b0	;
	end 	
	
	assign lw_stall = lw_stall_br | lw_stall_op	;
		
	//delayed version of lw_stall to skip iw follwed by dependent instruction of load instruction and maintain the dependent instruction
	always @(posedge clk)
	begin
		lw_stall_del			<=	lw_stall			;
	end 
	
	//save the PC and IW when there is a lw_stall
	
	always @(*)
	begin
		if(lw_stall)
		begin
			pc_stall = pc_in		;
			iw_stall = iw_in		;
		end 
		else
		begin
			pc_stall = pc_stall	;
			iw_stall = iw_stall	;
		end
	end 
	
	assign lw_stall_flag_to_IF	= 	lw_stall			;
	assign lw_stall_pc_to_IF	=	pc_stall			;
	assign lw_stall_iw_to_IF	=	iw_stall			;			
	
	
	//data Hazard detection 
	//For Rs1
	always @(*)
	begin
		if((regif_rs1_reg == df_ex_reg) && df_ex_enable && (regif_rs1_reg != 0))
			rs1_data_out_buff	<=	df_ex_data	;
		else if((regif_rs1_reg == df_mem_reg) && df_mem_enable && (regif_rs1_reg != 0))
			rs1_data_out_buff	<=	df_mem_data	;
		else if((regif_rs1_reg == df_wb_reg) && df_wb_enable && (regif_rs1_reg != 0))
			rs1_data_out_buff	<=	df_wb_data	;
		else
			rs1_data_out_buff	<=	regif_rs1_data				;
	end 
	//For Rs2
	always @(*)
	begin
		if((regif_rs2_reg == df_ex_reg) && df_ex_enable && (regif_rs2_reg != 0))
			rs2_data_out_buff	<=	df_ex_data	;
		else if((regif_rs2_reg == df_mem_reg) && df_mem_enable && (regif_rs2_reg != 0))
			rs2_data_out_buff	<=	df_mem_data	;
		else if((regif_rs2_reg == df_wb_reg) && df_wb_enable && (regif_rs2_reg != 0))
			rs2_data_out_buff	<=	df_wb_data	;
		else
			rs2_data_out_buff	<=	regif_rs2_data				;
	end 
	
	
	
	assign rs1_data_in_temp = rs1_data_out_buff				;
	assign rs2_data_in_temp = rs2_data_out_buff				;
	
		
	//comb always block for immediate values 
	always@(*)
	begin
		case(opcode)
			
				//For I-type,funct7 and rs2 are replaced by 12-bit immediate
				I_type_JALR,I_type_LOAD,I_type_ALU:
				
						signex_or_up_immediate	=	{{20{iw_in[31]}},iw_in[31:20]}	;
						
				//For S-type,funct7 and rd are replaced by 12-bit immediate
				S_type:						
				
						signex_or_up_immediate	=	{{20{iw_in[31]}},iw_in[31:25],iw_in[11:7]}	;
				
				//For B-type,funct7 and rd are replaced by 13-bit immediate in 12-bit format i.e 0th bit is discarded because it is always '0'
				B_type:
				
						signex_or_up_immediate	=	{{20{iw_in[31]}},iw_in[7],iw_in[30:25],iw_in[11:8],1'b0}	;//This can be considered as left shift by 1 or multiplication by 2 
				
				//For U-type,funct7,rs2,rs1 are replaced by 20-bit upper immediate
				U_type_LUI,U_type_AUIPC:
						
						signex_or_up_immediate	=	{iw_in[31:12],{12{1'b0}}}	;
	
				//For J-type,funct7 and rd are replaced by 21-bit immediate in 20-bit format i.e 0th bit is discarded because it is always '0'
				J_type:
				
						signex_or_up_immediate	=	{{12{iw_in[31]}},iw_in[19:12],iw_in[20],iw_in[30:21],1'b0}	;//This can be considered as left shift by 1 or multiplication by 2 
		
				default:signex_or_up_immediate = signex_or_up_immediate	;
		endcase
	end
	
	//generating the jump enable and jump address 
	always @(*)
	begin
		case(opcode)
			J_type:
			begin
				jump_enable	<=	1'b1										;
				jump_addr	<=	pc_in + signex_or_up_immediate	;
			end
			
			I_type_JALR:
			begin
				jump_enable	<=	1'b1										;
				jump_addr	<=	rs1_data_out_buff + signex_or_up_immediate	;
			end
			
			B_type:
					case(funct3)
						BEQ:
						begin
							if(rs1_data_in_temp == rs2_data_in_temp)
							begin
								jump_enable	<=	1'b1										;
								jump_addr	<=	pc_in + signex_or_up_immediate	;
							end
							else
							begin
								jump_enable	<=	1'b0										;
								jump_addr	<=	jump_addr								;
							end 
						end
						BNE:
						begin
							if(rs1_data_in_temp != rs2_data_in_temp)
							begin
								jump_enable	<=	1'b1										;
								jump_addr	<=	pc_in + signex_or_up_immediate	;
							end
							else
							begin
								jump_enable	<=	1'b0										;
								jump_addr	<=	jump_addr								;
							end  
						end
						BLT:
						begin
							if(rs1_data_in_temp < rs2_data_in_temp)
							begin
								jump_enable	<=	1'b1										;
								jump_addr	<=	pc_in + signex_or_up_immediate	;
							end
							else
							begin
								jump_enable	<=	1'b0										;
								jump_addr	<=	jump_addr								;
							end  
						end
						BGE:
						begin
							if(rs1_data_in_temp >= rs2_data_in_temp)
							begin
								jump_enable	<=	1'b1										;
								jump_addr	<=	pc_in + signex_or_up_immediate	;
							end
							else
							begin
								jump_enable	<=	1'b0										;
								jump_addr	<=	jump_addr								;
							end  
						end
						BLTU:
						begin
							if({1'b0,rs1_data_out_buff}<={1'b0,rs2_data_out_buff})
							begin
								jump_enable	<=	1'b1										;
								jump_addr	<=	pc_in + signex_or_up_immediate	;
							end
							else
							begin
								jump_enable	<=	1'b0										;
								jump_addr	<=	jump_addr								;
							end  
						end
						BGEU:
						begin
							if({1'b0,rs1_data_out_buff}>={1'b0,rs2_data_out_buff})
							begin
								jump_enable	<=	1'b1										;
								jump_addr	<=	pc_in + signex_or_up_immediate	;
							end
							else
							begin
								jump_enable	<=	1'b0										;
								jump_addr	<=	jump_addr								;
							end  
						end
						default:begin jump_enable <=	1'b0	; jump_addr	<=	jump_addr	;	end 
					endcase
			default:begin jump_enable <=	1'b0	; jump_addr	<=	jump_addr	;	end 	
		endcase
	end
	
	//assign jump_enable_out 	= jump_enable	;
	assign jump_enable_out 	= jump_enable_rsg	;
	assign jump_addr_out		= jump_addr			;
	
	
	//delayed version of jump enable to skip iw follwed by branch instruction as well as to skip the back to back jumps
	always @(posedge clk)
	begin
		jump_enable_del		<=	jump_enable			;
		jump_enable_rsg_del	<=	jump_enable_rsg	;
	end 
	
assign jump_enable_rsg = jump_enable & ~jump_enable_del	;

		
	
		
	//register the outputs which are going to EX stage 
	always @(posedge clk)
	begin
		rs1_data_out					<=	rs1_data_out_buff				;
	   rs2_data_out					<=	rs2_data_out_buff				;
		pc_out							<=	pc_in								;
		signex_or_up_immediate_out	<=	signex_or_up_immediate		;
	end 
	
	always @(posedge clk)
	begin
		if(jump_enable_rsg_del || lw_stall)
		begin
			iw_out		<=	32'h00000013	;
			wb_reg_out	<=	5'd0				;
		end
		else
		begin
			iw_out		<=	iw_in				;
			wb_reg_out	<=	iw_in[11:7]		;
		end
	end 
	
		//generating wb_enable 
	always @(posedge clk)
	begin
		//wb_reg_out	<=	iw_in[11:7]		;
		case(opcode)
			R_type,I_type_LOAD,I_type_ALU,U_type_LUI,U_type_AUIPC,J_type:
			begin
				wb_enable_out	<=	1'b1	;	
			end
			default:	
				wb_enable_out	<=	1'b0	;
		endcase
	end 
	
	//Halt detection 
	always @(*)
	begin
		if(reset)
			halt_flag	<=	1'b0	;
		//else if((iw_in[20] == 1'b1)&&(iw_in[6:0] == 7'b1110011))  //This is the decoding of instruction for EBREAK instruction 
		else if(iw_in == E_BREAK)
			halt_flag	<=	1'b1	;
		else
			halt_flag	<=	halt_flag	;
	end 
	
	//debug signals 
	assign iw_debug_ID = iw_in	;
	assign pc_debug_ID = pc_in	;
	
endmodule 