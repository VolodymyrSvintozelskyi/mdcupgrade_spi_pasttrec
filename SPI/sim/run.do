restart -f
delete wave *
add wave -position end  sim:/tb_loader/CLK
add wave -position end  sim:/tb_loader/BUS_RX
add wave -position end  sim:/tb_loader/BUS_TX
add wave -position end  sim:/tb_loader/RST_IN
add wave -position end  sim:/tb_loader/SPI_CS_OUT
add wave -position end  sim:/tb_loader/SPI_SDI_IN
add wave -position end  sim:/tb_loader/SPI_SDO_OUT
add wave -position end  sim:/tb_loader/SPI_SCK_OUT
add wave -position end  sim:/tb_loader/SPI_CLR_OUT
add wave -position end  sim:/tb_loader/SPI_CS_OUT(0)
add wave -position end  sim:/tb_loader/SPI_SDO_OUT(0)
add wave -position end  sim:/tb_loader/SPI_SCK_OUT(0)

add wave -position end -radix hexadecimal sim:/tb_loader/dut/SPI_INTERFACE/ram



add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/override_cs
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/override_sck
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/override_sdo
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/invert_cs
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/invert_sck
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/invert_sdo
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/clear_reg
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/word_length
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/wait_cycles
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/ctrl_reg
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/chipselect_reg
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/sudolock
run 80000ns
wave zoom full