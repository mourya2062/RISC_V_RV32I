# RISC_V_RV32I

Hardware Used : DE10-Lite 
Clock Frequency : 10 MHz

How To Use Those Files :
Note:Vivado Users remove the altera_clk IP core and instantiate BUFG instead 

1)Install the riscv_gcc compiler from github 
2)Copy all the files into your IDE tool(vivado,Quartus)
3)Map the top module I/O ports to Valid I/O banks 
4)Create a Integrated Logic Analyzer(ILA,Vivado) or Signla Tap Analyzer(Quartus) and instantiate that by removing the existing tap analyzer 
5)Vivado users can replace the memory file as per the xilinx (I recommend to use a BRAM IP Core),we use that memory to store the .hex(actual c program converted or compiled to .hex file by riscv gcc compiler)
6)Generate .bit file(vivado) and .sof file(quartus) and you can test the file

If you have any doubts ,reach me at mouryabc@outlook.com
