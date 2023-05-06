module rv32_ex
(
		//system clock and synchronous reset 
		input clk												,
		input reset												,
	 
		//From id stage 
	 
		input 		[31:0] 	pc_in							,
		input 		[31:0] 	iw_in							,
		input 		[31:0] 	rs1_data_in_from_ID		,
		input 		[31:0] 	rs2_data_in_from_ID		,
		input 		[4:0]		wb_reg_in					,
		input						wb_enable_in				,
		input 		[31:0]	signex_or_up_immediate	,
	 
		// to mem
		output reg 	[31:0] 	pc_out						,
		output reg 	[31:0] 	iw_out						,
		output reg 	[31:0] 	alu_out						,
		output reg 	[4:0] 	wb_reg_out					,
		output reg 				wb_enable_out				,
		output reg				mem_io_oper_re				,//alias writeback from memory 
		output reg				mem_io_oper_we				,
		output reg	[31:0]	mem_io_wr_data				,
		
		//to id stage for hazard detection 
		output					df_ex_enable				,
		output		[4:0]		df_ex_reg					,
		output 		[31:0]	df_ex_data					,
		
		//Load hazard detection to ID stage 
		output 					df_wb_from_mem_ex			,
		
		//Load hazard detection from write back 
		input 					df_wb_from_mem_wb			,
		input			[4:0]		df_wb_reg					,
		input			[31:0]	df_wb_data					
		
	 );
	
	//Instruction types 
	
	//R-type
	parameter	R_type		=	7'b0110011		;
	parameter 	ADD			=	10'b0000000000	;//concatination of funct7&funct3
	parameter 	SUB			=	10'b0100000000	;
	parameter 	SLL			=	10'b0000000001	;
	parameter 	SLT			=	10'b0000000010	;
	parameter 	SLTU			=	10'b0000000011	;
	parameter 	XOR			=	10'b0000000100	;
	parameter 	SRL			=	10'b0000000101	;
	parameter 	SRA			=	10'b0100000101	;
	parameter 	OR 			=	10'b0000000110	;
	parameter 	AND			=	10'b0000000111	;

	//I-type ,System instructions are not included as they don't belong to ALU
	//JUMP AND LINK	
	parameter	I_type_JALR	=	7'b1100111	;
	//MEMORY LOAD OPERATIONS
	parameter	I_type_LOAD	=	7'b0000011	;	
	parameter	LB				=	3'b000		;//funct3
	parameter	LH				=	3'b001		;
	parameter	LW				=	3'b010		;
	parameter	LBU			=	3'b100		;
	parameter 	LHU			=	3'b101		;
	//ADDI,SLTI---AND LOGICAL OPERATIONS
	parameter	I_type_OPER	=	7'b0010011	;	
	parameter	ADDI			=	3'b000		;//funct3
	parameter	SLTI			=	3'b010		;
	parameter	SLTIU			=	3'b011		;
	parameter	XORI			=	3'b100		;
	parameter 	ORI			=	3'b110		;
	parameter	ANDI			=	3'b111		;
	parameter	SLLI			=	3'b001		;
	parameter	SRLAI			=	3'b101		;//shift right logical and arithmetic are differentiated by iw_in[30]
	
	//S-type 
	parameter	S_type		=	7'b0100011	;	
	parameter 	SB				=	3'b000		;
	parameter	SH				=	3'b001		;
	parameter	SW				=	3'b010		;
	//B-type
	parameter	B_type		=	7'b1100011	;	
	parameter 	BEQ			=	3'b000		;
	parameter	BNE			=	3'b001		;
	parameter	BLT			=	3'b100		;	
	parameter 	BGE			=	3'b101		;
	parameter	BLTU			=	3'b110		;
	parameter	BGEU			=	3'b111		;
	
	//U-type
	parameter	U_type_LUI	=	7'b0110111	;
	parameter	U_type_AUIPC=	7'b0010111	;
	//J-type
	parameter	J_type		=	7'b1101111	;	
	
	wire 			[6:0 ]	opcode							;
	wire 			[2:0 ] 	funct3							;
	wire 			[6:0 ] 	funct7							;
	wire			[4:0 ]	shamt								;//no of shifts for shift instructions 
	wire			[9:0 ]	R_type_control_bits			;
	reg			[31:0]	alu_out_comb					;
	reg						mem_io_oper_re_comb			;//this signal indicates the mem block that the instruction invloves memory 		
	reg						mem_io_oper_we_comb			;//this signal indicates the mem block that the instruction invloves memory 		
	reg			[31:0]	load_instr_temp_result		;
	
	reg  			[31:0] 	rs1_data_in						;
	reg	  		[31:0] 	rs2_data_in						;
	wire signed [31:0] 	rs1_data_in_temp				;
	wire signed [31:0] 	rs2_data_in_temp				;
	
	wire 			[4:0] 	regif_rs1_reg					;
	wire 			[4:0] 	regif_rs2_reg					;
	
	
	assign opcode 					= 	iw_in[6:0]			;
	assign funct3					=	iw_in[14:12]		;
	assign shamt					=  iw_in[24:20]		;
	assign funct7					=	iw_in[31:25]		;
	assign R_type_control_bits	=	{funct7,funct3}	;
	
	
	assign 	regif_rs1_reg	=	iw_in[19:15]	;
	assign 	regif_rs2_reg	=	iw_in[24:20]	;
	
	//load hazard data forwardig from WB stage 
	//rs1
	always @(*)
	begin
		if(df_wb_from_mem_wb && (regif_rs1_reg == df_wb_reg))
		begin
			rs1_data_in	<=	df_wb_data	;
		end 
		else
		begin
			rs1_data_in	<=	rs1_data_in_from_ID	;
		end
	end 
	
	//rs2
	always @(*)
	begin
		if(df_wb_from_mem_wb && (regif_rs2_reg == df_wb_reg))
		begin
			rs2_data_in	<=	df_wb_data	;
		end 
		else
		begin
			rs2_data_in	<=	rs2_data_in_from_ID	;
		end
	end 
	
	
	assign rs1_data_in_temp = rs1_data_in				;
	assign rs2_data_in_temp = rs2_data_in				;

	//comb always block for computation
	always@(*)
	begin
		case(opcode)
				R_type:
					case(R_type_control_bits)
						ADD:
							alu_out_comb	<=	rs1_data_in + rs2_data_in													;
						SUB:
							alu_out_comb	<=	rs1_data_in - rs2_data_in													;
						SLL:
							alu_out_comb	<=	rs1_data_in << rs2_data_in[4:0]											;
						SLT:
							alu_out_comb	<=	(rs1_data_in_temp < rs2_data_in_temp)?1'b1:1'b0						;
						SLTU:
							alu_out_comb	<=	(rs1_data_in < rs2_data_in)?1'b1:1'b0									;
						XOR:
							alu_out_comb	<=	rs1_data_in ^ rs2_data_in													;
						SRL:
							alu_out_comb	<=	rs1_data_in >> rs2_data_in[4:0]											;
						SRA:
							alu_out_comb	<=	rs1_data_in >>> rs2_data_in[4:0]											;
						OR:
							alu_out_comb	<=	rs1_data_in | rs2_data_in													;
						AND:
							alu_out_comb	<=	rs1_data_in & rs2_data_in													;
							
						default:alu_out_comb <= 32'h0																			;
					endcase
					
				I_type_JALR,J_type:
					alu_out_comb	<=	pc_in + 32'h00000004																	;	
				
				I_type_LOAD://mentioned all the instructions for clarity, anyway tool will optimize it 
					case(funct3)
						LB,LH,LW,LBU,LHU:
							begin
								alu_out_comb			<=	rs1_data_in + 	signex_or_up_immediate							;
							end
							
						default:begin alu_out_comb <= 32'h0	;	end 
					endcase
				
				I_type_OPER:
					case(funct3)
						ADDI:
							alu_out_comb	<=	rs1_data_in + 	signex_or_up_immediate									;
						SLTI:
							alu_out_comb	<=	(rs1_data_in < signex_or_up_immediate)?1'b1:1'b0					;
						SLTIU:
							alu_out_comb	<=	({1'b0,rs1_data_in} < {1'b0,signex_or_up_immediate})?1'b1:1'b0	;
						XORI:
							alu_out_comb	<=	rs1_data_in ^ signex_or_up_immediate									;
						ORI:
							alu_out_comb	<=	rs1_data_in | signex_or_up_immediate									;
						ANDI:
							alu_out_comb	<=	rs1_data_in & signex_or_up_immediate									;
						SLLI:
							alu_out_comb	<=	rs1_data_in << shamt															;//u can use signex_or_up_immediate[4:0] instead of shamt but shamt is used for clarity 
						
						//Shift Right Logic and arithmetic are differentiated by 30th bit of instruction word 
						SRLAI:
						begin
							if(iw_in[30])
								alu_out_comb	<=	rs1_data_in >>> shamt													;
							else
								alu_out_comb	<=	rs1_data_in >> shamt														;
						end 
						
						default:alu_out_comb <= 32'h0																			;
					endcase
					
				S_type://mentioned all the instructions for clarity, anyway tool will optimize it 
					case(funct3)
						SB,SH,SW:
							begin
								alu_out_comb			<=	rs1_data_in + 	signex_or_up_immediate							;
							end
								
						default:begin alu_out_comb <= 32'h0	;	end 
					endcase	
	
				U_type_LUI:
					alu_out_comb	<=	signex_or_up_immediate																;
					
				U_type_AUIPC:
					alu_out_comb	<=	pc_in + signex_or_up_immediate													;
					
				default:begin alu_out_comb <= 32'h0	;	end 			
		endcase	
	end	
	
	always @(*)
	begin
		case(opcode)
			I_type_LOAD://mentioned all the instructions for clarity, anyway tool will optimize it 
					case(funct3)
						LB,LH,LW,LBU,LHU:
							begin
								mem_io_oper_re_comb	<=	1'b1																		;
								mem_io_oper_we_comb	<=	1'b0																		;
							end
					 endcase
			S_type://mentioned all the instructions for clarity, anyway tool will optimize it 
					case(funct3)
						SB,SH,SW:
							begin
								mem_io_oper_we_comb	<=	1'b1																		;
								mem_io_oper_re_comb	<=	1'b0																		;
							end
					endcase	
							
			default:begin mem_io_oper_re_comb <=	1'b0	; mem_io_oper_we_comb <=	1'b0	;	end 
		endcase
	end
		


	always @(posedge clk)
	begin
		if(reset)
			alu_out	<=	32'b0								;//intentionally skipped everything except alu_out because remaining will be done in the previous stage  
		else
			alu_out			<=	alu_out_comb			;
			mem_io_oper_re	<=	mem_io_oper_re_comb	;
			mem_io_oper_we	<=	mem_io_oper_we_comb	;
			mem_io_wr_data	<=	rs2_data_in				;//source for all the store instruction is register 2 
			pc_out			<=	pc_in						;
			iw_out			<=	iw_in						;
			wb_reg_out		<=	wb_reg_in				;
			wb_enable_out	<=	wb_enable_in			;
	end 
	
	//data hazard detection required signlas 
	assign df_ex_enable	=	wb_enable_in	;
	assign df_ex_reg		=	wb_reg_in		;
	assign df_ex_data		=	alu_out_comb	;
	
	//Load hazard detection required signal to ID block 
	assign df_wb_from_mem_ex	=	mem_io_oper_re_comb	;
	
	
	
							
endmodule