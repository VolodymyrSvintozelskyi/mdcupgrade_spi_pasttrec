restart -f
delete wave *


add wave -position 0  sim:/system_testbench/CLK
add wave -position 1 -radix hexadecimal sim:/system_testbench/BUS_RX
add wave -position 2 -radix hexadecimal sim:/system_testbench/BUS_TX
add wave -position 3  sim:/system_testbench/RST_IN

add wave -position end  sim:/system_testbench/SPI_CS_OUT
add wave -position end  sim:/system_testbench/SPI_SDI_IN
add wave -position end  sim:/system_testbench/SPI_SDO_OUT
add wave -position end  sim:/system_testbench/SPI_SCK_OUT
add wave -position end  sim:/system_testbench/SPI_RST_OUT

add wave -position end  sim:/system_testbench/dut/SPI_INTERFACE/readback

add wave -position end -radix hexadecimal sim:/system_testbench/dut/spi_active_bunch
add wave -position end -radix hexadecimal sim:/system_testbench/dut/load_chipid
add wave -position end -radix hexadecimal sim:/system_testbench/dut/load_all
add wave -position end  sim:/system_testbench/dut/load_trigger
add wave -position end -radix hexadecimal sim:/system_testbench/dut/load_num
add wave -position end -radix hexadecimal sim:/system_testbench/dut/load_addr
add wave -position end -radix hexadecimal sim:/system_testbench/dut/load_past_id

#add wave -position end  sim:/system_testbench/dut/spi_fsm_state
#add wave -position end  sim:/system_testbench/dut/autoload_addr
#add wave -position end  sim:/system_testbench/dut/autoload_chipid
#add wave -position end  sim:/system_testbench/dut/autoload_en
#add wave -position end  sim:/system_testbench/dut/autoload_num
#add wave -position end  sim:/system_testbench/dut/MEMORY/dout2
#add wave -position end  sim:/system_testbench/dut/MEMORY/ram

add wave -position end  sim:/system_testbench/PASTTREC1/bitcounter
add wave -position end  sim:/system_testbench/PASTTREC1/rstcounter
add wave -position end -radix hexadecimal sim:/system_testbench/PASTTREC1/ram
add wave -position end  sim:/system_testbench/PASTTREC2/bitcounter
add wave -position end  sim:/system_testbench/PASTTREC2/rstcounter
add wave -position end -radix hexadecimal sim:/system_testbench/PASTTREC2/ram
add wave -position end  sim:/system_testbench/PASTTREC3/bitcounter
add wave -position end  sim:/system_testbench/PASTTREC3/rstcounter
add wave -position end -radix hexadecimal sim:/system_testbench/PASTTREC3/ram
add wave -position end  sim:/system_testbench/PASTTREC4/bitcounter
add wave -position end  sim:/system_testbench/PASTTREC4/rstcounter
add wave -position end -radix hexadecimal sim:/system_testbench/PASTTREC4/ram
add wave -position end  sim:/system_testbench/PASTTREC5/bitcounter
add wave -position end  sim:/system_testbench/PASTTREC5/rstcounter
add wave -position end -radix hexadecimal sim:/system_testbench/PASTTREC5/ram
add wave -position end  sim:/system_testbench/PASTTREC6/bitcounter
add wave -position end  sim:/system_testbench/PASTTREC6/rstcounter
add wave -position end -radix hexadecimal sim:/system_testbench/PASTTREC6/ram


run 1500000ns
wave zoom full