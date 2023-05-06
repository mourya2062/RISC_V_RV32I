module edge_detector
	(
		input  			clock			,
		input  			signal      ,
		output  			pulse            
	);
	
	reg signal_del 	;
	reg signal_del2 	;
	
	always @(posedge clock)
	begin
		signal_del	<=	signal	;
		signal_del2	<=	signal_del	;
	end 
	
	assign pulse = signal_del & ~signal_del2	;
	
endmodule
		