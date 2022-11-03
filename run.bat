@REM
@REM Simple batch file to compile the design and run a 
@REM memory test in command line mode.
@REM Make sure Modelsim/Questa win64pe/win64 directory is 
@REM the search path.
@ECHO OFF

@ECHO Check if work library exists
IF NOT EXIST "work" (vlib work)

@ECHO Compile VHDL SDRAM Controller
vcom -quiet -2008 rtl/sdram_pack.vhd
vcom -quiet -2008 rtl/fsm.vhd 
vcom -quiet -2008 rtl/sdram_ctrl.vhd 

@ECHO Compile Micron Verilog Memory model
vlog -quiet testbench/mt48lc4m32b2.v

@ECHO Compile VHDL testbench
vcom -quiet -2008 testbench/utils.vhd
vcom -quiet -2008 testbench/random.vhd
vcom -quiet -2008 testbench/sdram_ctrl_tester.vhd
vcom -quiet -2008 testbench/sdram_ctrl_tb.vhd	

@ECHO Run simulation
vsim -quiet -batch -t ps work.sdram_ctrl_tb -do "nolog -r /*; run -all; quit -f" 

