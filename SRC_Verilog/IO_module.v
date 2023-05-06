module IO_module
	(
		input 					clk					,
		input 					reset					,
		input			[31:0]	io_addr				,
		output reg	[31:0]	io_rdata				,
		input						io_we					,
		input			[3:0]		io_be					,
		input			[31:0]	io_wdata				,
		//BUTTON PERIPHERAL
		input 					PUSH_KEY				,
		output 		[3:0]		LEDS					
	);
	
	 //Peripheral Base Addresses 
	 parameter BUTTONS  			= 32'h80000000	;//allocated 16 bytes of memory to switches or push buttons 
	 parameter _LEDS				= 32'h80000010	;//allocated 16 bytes of memory to LED's  
	 // BUTTONS OFFSET
    parameter PUSH_BUTTON   	= 4'd0			;
	 
	 //LEDS OFFSET
	 parameter LED_0				= 4'd0			;
	 parameter LED_1				= 4'd4			;
	 parameter LED_2				= 4'd8			;
	 parameter LED_3				= 4'd12			;
	 
	 wire [105:0] debug_data	; 
	 reg [3:0]	LED_data			;
	 wire [3:0]	LED_NUM			;
	 

	 
	 always @ (posedge clk)
    begin
		if(reset)
			io_rdata 	<=	32'd0	;
      else if (io_addr[31:4] == BUTTONS[31:4]) //PUSH BUTTON PERIPHERAL
            case (io_addr[3:0])
                PUSH_BUTTON: 
                    io_rdata = PUSH_KEY			;
					 default:io_rdata	<=	32'd0	;
            endcase
      else if(io_addr[31:4] == _LEDS[31:4])		//LED PERIPHERAL
		begin
            case (LED_NUM)
                LED_0: 
                    io_rdata <= LED_data[0] 			;
                LED_1: 
                    io_rdata <= LED_data[1] 			;
                LED_2: 
                    io_rdata <= LED_data[2] 			;
                LED_3: 
                    io_rdata <= LED_data[3] 			;
            endcase
		end 
		else
           io_rdata	<=	32'd0	;
    end 
	 
	 assign LED_NUM = io_addr[3:0]	;
	 //LED PERIPHERAL 
	 always @ (posedge clk)
    begin
		if(reset)
			LED_data 	<=	4'd0	;
      else if ((io_addr[31:4] == _LEDS[31:4]) && (io_we == 1'b1))
		begin
            case (LED_NUM)
                LED_0: 
                    LED_data[0] <= io_wdata[0]		;
                LED_1: 
                    LED_data[1] <= io_wdata[0]		;
                LED_2: 
                    LED_data[2] <= io_wdata[0]		;
                LED_3: 
                    LED_data[3] <= io_wdata[0]		;
            endcase
		end 
    end 
	 
	 assign LEDS = LED_data	;
	 
//	 assign debug_data[31:0]  		= io_addr	;
//	 assign debug_data[63:32]  	= io_rdata	;
//	 assign debug_data[95:64]  	= io_wdata	;
//	 assign debug_data[99:96]  	= io_be		;
//	 assign debug_data[103:100]  	= LED_data	;
//	 assign debug_data[104]  		= io_we		;
//	 assign debug_data[105]  		= PUSH_KEY	;
//	 
//	 	IO_MODULE_ILA IO_ILA 
//		(
//			.acq_data_in    (debug_data)	,  //     tap.acq_data_in
//			.acq_trigger_in (reset)			, 	//    .acq_trigger_in
//			.acq_clk        (clk)         	// 	acq_clk.clk
//		);
	
endmodule 
	