module Risc_V_Stage_7
(
	input 			ADC_CLK_10			,
	input 	[1:0]	KEY					,
	output	[9:0] LEDR
);

	wire ADC_CLK_10_buff	;
	//IF stage signals 
	wire 	[31:0] 	memif_IM_addr_sig					;
	wire	[31:0]	memif_IM_data_sig					;
	wire	[31:0]	pc_out_if_out_id_in				;
	wire	[31:0]	iw_out_if_out_id_in				;
	
	//ID stage signals 	
	wire	[31:0]	pc_out_id_out_ex_in				;
	wire	[31:0]	iw_out_id_out_ex_in				;
	wire	[4:0]		wb_reg_out_id_out_ex_in			;
	wire				wb_enable_out_id_out_ex_in		;
	wire	[31:0]	rs1_data_id_out_ex_in			;
	wire	[31:0]	rs2_data_id_out_ex_in			;
	wire				halt_flag_sig						;
	
	//EX stage signlas 
	wire	[31:0]	pc_out_ex_out_mem_in				;
	wire	[31:0]	iw_out_ex_out_mem_in				;
	wire	[4:0]		wb_reg_out_ex_out_mem_in		;
	wire				wb_enable_out_ex_out_mem_in	;
	wire 	[31:0]	alu_result_ex_out_mem_in		;
	wire				mem_io_oper_re						;
	wire				mem_io_oper_we						;
	wire	[31:0]	mem_io_wr_data						;
	
	//MEM stage signals
	wire 	[31:0] 	memif_DM_addr_sig					;
	wire	[31:0]	memif_DM_data_sig					;
	wire				memif_DM_we							;
	wire	[3:0]		memif_DM_be							;
	wire	[31:0]	memif_DM_wdata						;
	wire	[31:0]	pc_out_mem_out_wb_in				;
	wire	[31:0]	iw_out_mem_out_wb_in				;
	wire	[4:0]		wb_reg_out_mem_out_wb_in		;
	wire				wb_enable_out_mem_out_wb_in	;
	wire 	[31:0]	alu_result_mem_out_wb_in		;
	
	wire	[31:0]	memif_rdata_to_WB					;
	wire	[31:0]	io_rdata_to_WB						;
	wire				mem_io_oper_re_to_WB				;
	
	//register Module interface signals 
	wire	[4:0]		regif_rs1_reg_sig					;
	wire	[4:0]		regif_rs2_reg_sig					;
	wire 				regif_wb_enable_sig				;
	wire 	[4:0]		regif_wb_reg_sig					;
	wire	[31:0]	regif_wb_data_sig					;
	wire 	[31:0]	regif_rs1_data_sig				;
   wire	[31:0]	regif_rs2_data_sig				;
	
	//data hazard related signals 
	//from ex
	wire				df_ex_enable						;
	wire	[4:0]		df_ex_reg							;
	wire 	[31:0]	df_ex_data							;
	//from mem
	wire				df_mem_enable						;
	wire	[4:0]		df_mem_reg							;
	wire 	[31:0]	df_mem_data							;
	//from wb
	wire				df_wb_enable						;
	wire	[4:0]		df_wb_reg							;
	wire 	[31:0]	df_wb_data							;
	wire  [31:0]	signex_or_up_immediate			;
	//IO Module signals
	
	wire	[31:0]	io_addr_sig							;
	wire	[31:0]	io_rdata_sig						;
	wire				io_we_sig							;
	wire	[3:0]		io_be_sig							;
	wire	[31:0]	io_wdata_sig						;
	wire 				PUSH_KEY_sig						;
	wire	[3:0]		LEDS_sig								;	
	
	//control hazard signals 
		//between ID and IF
	wire 				jump_enable							;
	wire	[31:0]	jump_addr							;
	
	wire				reset_sig_pulse					;
	reg				reset_sig_del1						;
	reg				reset_sig_del2						;
	reg				reset_sig_del3						;
	wire				reset_sig							;
	
	//Load Hazard related signals 
	wire				df_wb_from_mem_ex					;
	wire				df_wb_from_mem_mem				;
	wire				df_wb_from_mem_wb					;
	
	wire				lw_stall_flag						;
	wire	[31:0]	lw_stall_pc							;
	wire	[31:0]	lw_stall_iw							;
	wire	[31:0]	iw_debug_ID							;
	wire	[31:0]	pc_debug_ID							;
	
	
	
	wire  [599:0]	debug_data							;
	
	RV32_clk BUFG (
		.inclk  (ADC_CLK_10),  //  altclkctrl_input.inclk
		.outclk (ADC_CLK_10_buff)  // altclkctrl_output.outclk
	);
	
	edge_detector edge_detector_counter_en 
(
	.clock(ADC_CLK_10_buff)						,
	.signal(~KEY[0])      						,
	.pulse(reset_sig_pulse)            
);

always @(posedge ADC_CLK_10_buff)
begin
	reset_sig_del1	<=	reset_sig_pulse		;
	reset_sig_del2	<=	reset_sig_del1			;
	reset_sig_del3	<=	reset_sig_del2			;
end

assign reset_sig	= reset_sig_pulse | reset_sig_del1 | reset_sig_del2 | reset_sig_del3	;

	
	edge_detector edge_detector_push 
(
	.clock(ADC_CLK_10_buff)						,
	.signal(~KEY[1])      						,
	.pulse(PUSH_KEY_sig)            
);
	
//As the memory is word addressable and we receive byte addresses from PC and alu_out 
//we have to divide the address by 4 .So, i_addr and d_addr are right shifted by 2 
sync_dual_port_ram RAM_inst
(
	.clk(ADC_CLK_10_buff)											,
	.i_addr(memif_IM_addr_sig >> 2)								,	
	//.i_addr(memif_IM_addr_sig)			,	
	.i_rdata(memif_IM_data_sig)									,
	.d_addr(memif_DM_addr_sig >> 2)								,
	//.d_addr(memif_DM_addr_sig)								,
	.d_rdata(memif_DM_data_sig)									,
	.d_we(memif_DM_we)												,
	.d_be(memif_DM_be)												,
	.d_wdata(memif_DM_wdata)
);

IO_module IO_module_inst
(
	.clk(ADC_CLK_10_buff) 											,	// input  clk_sig
	.reset(reset_sig) 												,	// input  reset_sig
	.io_addr(io_addr_sig) 											,	// input [31:0] io_addr_sig
	.io_rdata(io_rdata_sig) 										,	// output [31:0] io_rdata_sig
	.io_we(io_we_sig) 												,	// input  io_we_sig
	.io_be(io_be_sig) 												,	// input [3:0] io_be_sig
	.io_wdata(io_wdata_sig) 										,	// input [31:0] io_wdata_sig
	.PUSH_KEY(~KEY[1]) 												,	// input  PUSH_KEY_sig
	.LEDS(LEDS_sig) 														// output [3:0] LEDS_sig
);

assign LEDR = {6'd0,LEDS_sig}	;

rv32_if_top rv32_if_top_inst
(
	.clk(ADC_CLK_10_buff) 											,	// input  clk_sig
	.reset(reset_sig) 												,	// input  reset_sig
	.memif_addr(memif_IM_addr_sig) 								,	// output [31:0] memif_addr_sig
	.memif_data(memif_IM_data_sig) 								,	// input [31:0] memif_data_sig
	.pc_out(pc_out_if_out_id_in) 									,	// output [31:0] pc_out_sig
	.iw_out(iw_out_if_out_id_in) 									,	// output [31:0] iw_out_sig
	.halt_flag(halt_flag_sig)										,
	.jump_enable_in(jump_enable)									,
	.jump_addr_in(jump_addr)										,
	//stall signals from ID 
	.lw_stall_flag_from_ID(lw_stall_flag)						,
	.lw_stall_pc_from_ID(lw_stall_pc)							,
	.lw_stall_iw_from_ID(lw_stall_iw)			
);

rv32_id_top rv32_id_top_inst
(
	.clk(ADC_CLK_10_buff) 											,	// input  clk_sig
	.reset(reset_sig) 												,	// input  reset_sig
	.pc_from_IF(pc_out_if_out_id_in) 							,	// input [31:0] pc_in_sig
	.iw_from_IF(iw_out_if_out_id_in) 							,	// input [31:0] iw_in_sig
	.regif_rs1_reg(regif_rs1_reg_sig) 							,	// output [4:0] regif_rs1_reg_sig
	.regif_rs2_reg(regif_rs2_reg_sig) 							,	// output [4:0] regif_rs2_reg_sig
	.regif_rs1_data(regif_rs1_data_sig) 						,	// input [31:0] regif_rs1_data_sig
	.regif_rs2_data(regif_rs2_data_sig) 						,	// input [31:0] regif_rs2_data_sig
	.rs1_data_out(rs1_data_id_out_ex_in) 						,	// output [31:0] rs1_data_out_sig
	.rs2_data_out(rs2_data_id_out_ex_in) 						,	// output [31:0] rs2_data_out_sig
	.pc_out(pc_out_id_out_ex_in) 									,	// output [31:0] pc_out_sig
	.iw_out(iw_out_id_out_ex_in) 									,	// output [31:0] iw_out_sig
	.wb_reg_out(wb_reg_out_id_out_ex_in)						,	// output [4:0] wb_reg_out_sig
	.wb_enable_out(wb_enable_out_id_out_ex_in) 				,	// output  wb_enable_out_sig
	.halt_flag(halt_flag_sig)										,	// output  halt_flag_sig
	.signex_or_up_immediate_out(signex_or_up_immediate)	,
	//data hazard related signals 
	//from ex
	.df_ex_enable(df_ex_enable)									,
	.df_ex_reg(df_ex_reg)											,
	.df_ex_data(df_ex_data)											,
	//from mem
	.df_mem_enable(df_mem_enable)									,
	.df_mem_reg(df_mem_reg)											,
	.df_mem_data(df_mem_data)										,
	//from wb
	.df_wb_enable(df_wb_enable)									,
	.df_wb_reg(df_wb_reg)											,
	.df_wb_data(df_wb_data)											,
	//control hazard sig 
	.jump_enable_out(jump_enable)									,
	.jump_addr_out(jump_addr)										,
	//Load Hazard related signals 
	.df_wb_from_mem_ex(df_wb_from_mem_ex)						,
	.df_wb_from_mem_mem(df_wb_from_mem_mem)					,
	.lw_stall_flag_to_IF(lw_stall_flag)							,
	.lw_stall_pc_to_IF(lw_stall_pc)								,
	.lw_stall_iw_to_IF(lw_stall_iw)								,
	//debug signals 
	.iw_debug_ID(iw_debug_ID),
	.pc_debug_ID(pc_debug_ID)
);

rv32i_regs rv32i_regs_inst
(
	.clock(ADC_CLK_10_buff) 										,	// input  clock_sig
	.reset(reset_sig) 												,	// input  reset_sig
	.rs1_reg(regif_rs1_reg_sig) 									,	// input [Reg_depth_bits-1:0] rs1_reg_sig
	.rs2_reg(regif_rs2_reg_sig) 									,	// input [Reg_depth_bits-1:0] rs2_reg_sig
	.wb_enable(regif_wb_enable_sig) 								,	// input  wb_enable_sig
	.wb_reg(regif_wb_reg_sig) 										,	// input [Reg_depth_bits-1:0] wb_reg_sig
	.wr_data(regif_wb_data_sig) 									,	// input [Reg_width-1:0] wr_data_sig
	.rs1_data(regif_rs1_data_sig) 								,	// output [Reg_width-1:0] rs1_data_sig
	.rs2_data(regif_rs2_data_sig) 									// output [Reg_width-1:0] rs2_data_sig
);


rv32_ex rv32_ex_inst
(
	.clk(ADC_CLK_10_buff) 											,	// input  clk_sig
	.reset(reset_sig) 												,	// input  reset_sig
	.pc_in(pc_out_id_out_ex_in) 									,	// input [31:0] pc_in_sig
	.iw_in(iw_out_id_out_ex_in) 									,	// input [31:0] iw_in_sig
	.rs1_data_in_from_ID(rs1_data_id_out_ex_in) 						,	// input [31:0] rs1_data_in_sig
	.rs2_data_in_from_ID(rs2_data_id_out_ex_in) 						,	// input [31:0] rs2_data_in_sig
	.wb_reg_in(wb_reg_out_id_out_ex_in) 						,	// input [4:0] wb_reg_in_sig
	.wb_enable_in(wb_enable_out_id_out_ex_in) 				,	// input  wb_enable_in_sig
	.pc_out(pc_out_ex_out_mem_in) 								,	// output [31:0] pc_out_sig
	.iw_out(iw_out_ex_out_mem_in) 								,	// output [31:0] iw_out_sig
	.alu_out(alu_result_ex_out_mem_in) 							,	// output [31:0] alu_out_sig
	.wb_reg_out(wb_reg_out_ex_out_mem_in) 						,	// output [4:0] wb_reg_out_sig
	.wb_enable_out(wb_enable_out_ex_out_mem_in) 				,	// output  wb_enable_out_sig
	.signex_or_up_immediate(signex_or_up_immediate)			,
	.mem_io_oper_re(mem_io_oper_re)								,
	.mem_io_oper_we(mem_io_oper_we)								,
	.mem_io_wr_data(mem_io_wr_data)								,
	
	//data Hazard related signals to ID 
	.df_ex_enable(df_ex_enable)									,	//output 
	.df_ex_reg(df_ex_reg)											,	//output [4:0]
	.df_ex_data(df_ex_data)											,	//output [31:0]
	
	//Load hazard detection to ID stage 
	.df_wb_from_mem_ex(df_wb_from_mem_ex)						,
		
	//Load hazard detection from write back 
	.df_wb_from_mem_wb(df_wb_from_mem_wb)						,
	.df_wb_reg(df_wb_reg)											,
	.df_wb_data(df_wb_data)
	
);

rv32_mem_top rv32_mem_top_inst
(
	.clk(ADC_CLK_10_buff) 											,	// input  clk_sig
	.reset(reset_sig) 												,	// input  reset_sig
	
	//from EX 
	.pc_in(pc_out_ex_out_mem_in) 									,	// input [31:0] pc_in_sig
	.iw_in(iw_out_ex_out_mem_in) 									,	// input [31:0] iw_in_sig
	.alu_result_in(alu_result_ex_out_mem_in) 					,	// input [31:0] iw_in_sig
	.wb_reg_in(wb_reg_out_ex_out_mem_in) 						,	// input [4:0] wb_reg_in_sig
	.wb_enable_in(wb_enable_out_ex_out_mem_in) 				,	// input  wb_enable_in_sig
	.mem_io_oper_re(mem_io_oper_re)								,
	.mem_io_oper_we(mem_io_oper_we)								,
	.mem_io_wr_data(mem_io_wr_data)								,
	
	//to WB 
	.pc_out(pc_out_mem_out_wb_in) 								,	// output [31:0] pc_out_sig
	.iw_out(iw_out_mem_out_wb_in) 								,	// output [31:0] iw_out_sig
	.alu_result_out(alu_result_mem_out_wb_in) 				,	// output [31:0] alu_out_sig
	.wb_reg_out(wb_reg_out_mem_out_wb_in) 						,	// output [4:0] wb_reg_out_sig
	.wb_enable_out(wb_enable_out_mem_out_wb_in) 				,	// output  wb_enable_out_sig
	.memif_rdata_to_WB(memif_rdata_to_WB)						,
	.io_rdata_to_WB(io_rdata_to_WB)								,
	.mem_io_oper_re_to_WB(mem_io_oper_re_to_WB)				,
	
	
	//data memory interface 
	.memif_addr(memif_DM_addr_sig)								,	
	.memif_rdata(memif_DM_data_sig)								,	
	.memif_we(memif_DM_we)											,		
	.memif_be(memif_DM_be)											,		
	.memif_wdata(memif_DM_wdata)									,
	
	//io interface 
	.io_addr(io_addr_sig)											,	
	.io_rdata(io_rdata_sig)											,	
	.io_we(io_we_sig)													,		
	.io_be(io_be_sig)													,		
	.io_wdata(io_wdata_sig)											,	
	
	//Load Hazard signal
	.df_wb_from_mem_mem(df_wb_from_mem_mem)					,
	
	//Hazard related signals 
	.df_mem_enable(df_mem_enable)									,	//output 
	.df_mem_reg(df_mem_reg)											,	//output [4:0]
	.df_mem_data(df_mem_data)											//output [31:0]
);

rv32_wb_top rv32_wb_top_inst
(
	.clk(ADC_CLK_10_buff) 											,	// input  clk_sig
	.reset(reset_sig) 												,	// input  reset_sig
	.pc_in(pc_out_mem_out_wb_in) 									,	// input [31:0] pc_in_sig
	.iw_in(iw_out_mem_out_wb_in) 									,	// input [31:0] iw_in_sig
	.alu_result_in(alu_result_mem_out_wb_in) 					,	// input [31:0] alu_in_sig
	.wb_reg_in(wb_reg_out_mem_out_wb_in) 						,	// input [4:0] wb_reg_in_sig
	.wb_enable_in(wb_enable_out_mem_out_wb_in) 				,	// input  wb_enable_in_sig
	.regif_wb_enable(regif_wb_enable_sig) 						,	// output  regif_wb_enable_sig
	.regif_wb_reg(regif_wb_reg_sig) 								,	// output [4:0] regif_wb_reg_sig
	.regif_wb_data(regif_wb_data_sig) 							,	// output [31:0] regif_wb_data_sig
	.memif_rdata(memif_rdata_to_WB)								,
	.io_rdata(io_rdata_to_WB)										,
	.mem_io_oper_re(mem_io_oper_re_to_WB)						,
	
	//Load Hazard signal 
	.df_wb_from_mem_wb(df_wb_from_mem_wb)						,
	
	//Hazard related signals 
	.df_wb_enable(df_wb_enable)									,	//output 
	.df_wb_reg(df_wb_reg)											,	//output [4:0]
	.df_wb_data(df_wb_data)												//output [31:0]
);

	//32-bit
	assign debug_data[31:0]			=	pc_out_if_out_id_in				;
	assign debug_data[63:32]		=	pc_out_id_out_ex_in				;
	assign debug_data[95:64]		=	pc_out_ex_out_mem_in				;
	assign debug_data[127:96]		=	pc_out_mem_out_wb_in				;
	assign debug_data[159:128]		=	iw_out_if_out_id_in				;
	assign debug_data[191:160]		=	iw_out_id_out_ex_in				;
	assign debug_data[223:192]		=	iw_out_ex_out_mem_in				;
	assign debug_data[255:224]		=	iw_out_mem_out_wb_in				;
	assign debug_data[287:256]		=	iw_debug_ID     					;//DATA_IM_MEM
	assign debug_data[319:288]		=	regif_rs1_data_sig				;
	assign debug_data[351:320]		=	regif_rs2_data_sig				;
	assign debug_data[383:352]		=	rs1_data_id_out_ex_in			;
	assign debug_data[415:384]		=	rs2_data_id_out_ex_in			;
	assign debug_data[447:416]		=	regif_wb_data_sig					;
	assign debug_data[479:448]		=	alu_result_ex_out_mem_in		;
	assign debug_data[511:480]		=	alu_result_mem_out_wb_in		;
	//16-bit
	assign debug_data[527:512]		=	pc_debug_ID							;//ADDR_IM_MEM
	//5-bit
	assign debug_data[532:528]		=	regif_rs1_reg_sig					;
	assign debug_data[537:533]		=	regif_rs2_reg_sig					;
	assign debug_data[542:538]		=	wb_reg_out_id_out_ex_in			;
	assign debug_data[547:543]		=	wb_reg_out_ex_out_mem_in		;
	assign debug_data[552:548]		=	wb_reg_out_mem_out_wb_in		;
	assign debug_data[557:553]		=	regif_wb_reg_sig					;
	//1-bit 
	assign debug_data[558]			=	wb_enable_out_id_out_ex_in		;
	assign debug_data[559]			=	wb_enable_out_ex_out_mem_in	;
	assign debug_data[560]			=	wb_enable_out_mem_out_wb_in	;
	assign debug_data[561]			=	regif_wb_enable_sig				;
	assign debug_data[562]			=	reset_sig							;
	assign debug_data[563]			=	halt_flag_sig						; 
	assign debug_data[595:564]		=	jump_addr							;
	assign debug_data[596]			=	jump_enable							; 
	assign debug_data[597]			=	df_wb_from_mem_ex					; 
	assign debug_data[598]			=	df_wb_from_mem_mem				;
	assign debug_data[599]			=	lw_stall_flag						; 
	
	LAB5_ILA u0 (
		.acq_data_in    (debug_data)	,    	//        tap.acq_data_in
		.acq_trigger_in (reset_sig)	, 		//           .acq_trigger_in
		.acq_clk        (ADC_CLK_10_buff)	     //    acq_clk.clk
	);


endmodule 
