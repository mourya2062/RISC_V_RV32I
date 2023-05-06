module rv32_mem_top
(
	// system clock and synchronous reset
	input 					clk					,
	input 					reset					,
	
	// from ex
	input 		[31:0] 	pc_in					,
	input			[31:0] 	iw_in					,
	input			[31:0]	alu_result_in		,
	input 		[4:0] 	wb_reg_in			,
	input 					wb_enable_in		,
	input						mem_io_oper_re		,
	input						mem_io_oper_we		,
	input 		[31:0]	mem_io_wr_data		,
	
	//memory interface
	output		[31:0]	memif_addr			,
	input			[31:0]	memif_rdata			,
	output					memif_we				,
	output		[3:0]		memif_be				,
	output		[31:0]	memif_wdata			,
	
	//io interface
	output		[31:0]	io_addr				,
	input			[31:0]	io_rdata				,
	output					io_we					,
	output		[3:0]		io_be					,
	output		[31:0]	io_wdata				, 
	
	// to wb
	output reg 	[31:0] 	pc_out					,
	output reg 	[31:0] 	iw_out					,
	output reg 	[31:0] 	alu_result_out			,
	output reg 	[4:0] 	wb_reg_out				,
	output reg 				wb_enable_out			,
	output		[31:0]	memif_rdata_to_WB		,
	output		[31:0]	io_rdata_to_WB			,
	output reg				mem_io_oper_re_to_WB	,
	
	//Load hazard detection to ID stage 
	output 					df_wb_from_mem_mem	,
	
	//to id stage for hazard detection 
	output					df_mem_enable		,
	output		[4:0]		df_mem_reg			,
	output 		[31:0]	df_mem_data		
);

	wire				signed_0_unsigned_1			;
	wire 	[1:0]		width								; 
	wire	[1:0]		byte_addr						;
	wire 	[35:0]	d_be_wdata						;
	wire [105:0] 	debug_data						; 

	assign width					=	iw_in[13:12]														;//funct3[1:0]
	assign signed_0_unsigned_1	=	iw_in[14]															;//funct3[2]
	assign byte_addr				=	alu_result_in[1:0]												;//Last two bits of memory address
	
	assign d_be_wdata				=	ram_byte_enables_and_data(width,byte_addr,mem_io_wr_data)	;
	
	//for reading from memory
	assign memif_addr				=	alu_result_in														;//computed memory address for load instruction and store instruction 
	
	//for writing to memory
	assign memif_be 				= 	d_be_wdata[3:0]													;
	assign memif_wdata			=	d_be_wdata[35:4]													;
	assign memif_we				=	(mem_io_oper_we & (~alu_result_in[31]))? 1'b1 :1'b0	;			
	
	//for reading from io
	assign io_addr					=	alu_result_in														;
	
	//for writing to io
	assign io_be 					= 	d_be_wdata[3:0]													;
	assign io_wdata				=	d_be_wdata[35:4]													;
	assign io_we					=	(mem_io_oper_we & alu_result_in[31])? 1'b1 :1'b0		;			
			
			
	always @(posedge clk)
	begin
		alu_result_out				<=	alu_result_in				;
		pc_out						<=	pc_in							;
		iw_out						<=	iw_in							;
		wb_reg_out					<=	wb_reg_in					;
		wb_enable_out				<=	wb_enable_in				;
		mem_io_oper_re_to_WB		<=	mem_io_oper_re				;
	end 
	
	
	assign memif_rdata_to_WB	=	memif_rdata	;
	assign io_rdata_to_WB		=	io_rdata		;

	
	//data hazard detection required signlas 
	assign df_mem_enable	=	wb_enable_in			;
	assign df_mem_reg		=	wb_reg_in				;
	assign df_mem_data	=	alu_result_in			;
	
	//Load hazard detection required signal to ID block 
	assign df_wb_from_mem_mem	=	mem_io_oper_re	;
		
	
	
//	 assign debug_data[31:0]  		= alu_result_in		;
//	 assign debug_data[63:32]  	= iw_in					;
//	 assign debug_data[95:64]  	= io_wdata				;
//	 assign debug_data[99:96]  	= io_be					;
//	 assign debug_data[103:100]  	= 4'b0000				;
//	 assign debug_data[104]  		= io_we					;
//	 assign debug_data[105]  		= mem_io_oper_we		;
//	
//		 
//	 	IO_MODULE_ILA MEM_ILA 
//		(
//			.acq_data_in    (debug_data)	,  //     tap.acq_data_in
//			.acq_trigger_in (reset)			, 	//    .acq_trigger_in
//			.acq_clk        (clk)         	// 	acq_clk.clk
//		);
	
	/////////////////////////////////////////////////////////
	//////Functions 
	/////////////////////////////////////////////////////////	

	function [35:0] 	ram_byte_enables_and_data	;
		input [1:0] 	width 							;
		input	[1:0]		byte_addr						;
		input [31:0] 	data								;
		
		parameter BYTE 	= 2'd0	;
		parameter H_WORD 	= 2'd1	;
		parameter WORD 	= 2'd2	;
		
	begin
		case(width)
			BYTE		:
							case(byte_addr)
								2'd0:
								begin
									ram_byte_enables_and_data[3:0] = 4'b0001		;
									ram_byte_enables_and_data[35:4] = data			;
								end 
								2'd1:
								begin
									ram_byte_enables_and_data[3:0] = 4'b0010		;
									ram_byte_enables_and_data[35:4] = data	<< 8	;
								end 
								2'd2:
								begin
									ram_byte_enables_and_data[3:0] = 4'b0100		;
									ram_byte_enables_and_data[35:4] = data	<< 16	;
								end 
								2'd3:
								begin
									ram_byte_enables_and_data[3:0] = 4'b1000		;
									ram_byte_enables_and_data[35:4] = data	<< 24	;
								end 
							endcase 
							
			H_WORD	:
							case(byte_addr)
								2'd0:
								begin
									ram_byte_enables_and_data[3:0] = 4'b0011		;
									ram_byte_enables_and_data[35:4] = data			;
								end 
								2'd1:
								begin
									ram_byte_enables_and_data[3:0] = 4'b0110		;
									ram_byte_enables_and_data[35:4] = data	<< 8	;
								end 
								2'd2:
								begin
									ram_byte_enables_and_data[3:0] = 4'b1100		;
									ram_byte_enables_and_data[35:4] = data	<< 16	;
								end 
								
								default:
								begin 
									ram_byte_enables_and_data[3:0] = 4'b0000		;
									ram_byte_enables_and_data[35:4] = data			;
								end 
							endcase 
							
			WORD	:
							case(byte_addr)
								2'd0:
								begin
									ram_byte_enables_and_data[3:0] = 4'b1111		;
									ram_byte_enables_and_data[35:4] = data			;
								end 
								
								default:
								begin 
									ram_byte_enables_and_data[3:0] = 4'b0000		;
									ram_byte_enables_and_data[35:4] = data			;
								end  
							endcase 
							
			default:
			begin 
				ram_byte_enables_and_data[3:0] = 4'b0000		;
				ram_byte_enables_and_data[35:4] = data			;
			end 
		endcase
	end
	endfunction	

	
endmodule 