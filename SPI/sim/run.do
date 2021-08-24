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
add wave -position end  sim:/tb_loader/SPI_RST_OUT

add wave -position end  sim:/tb_loader/dut/MEMORY/ram


add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/word_length
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/wait_cycles
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/ctrl_reg

add wave -position end  sim:/tb_loader/dut/spi_fsm_state
add wave -position end  sim:/tb_loader/dut/sc_fsm_state

add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/BUS_DATA_OUT

add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/RESET_IN
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/BUS_READ_IN
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/BUS_WRITE_IN
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/BUS_ADDR_IN
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/BUS_DATA_IN

add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/start
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/fsm_state

add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/RAM_BUSY
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/RAM_OFFSET
add wave -position end  sim:/tb_loader/dut/SPI_INTERFACE/RAM_DATA

add wave -position end  sim:/tb_loader/dut/load_en
add wave -position end  sim:/tb_loader/dut/load_chipid
add wave -position end  sim:/tb_loader/dut/load_en
add wave -position end  sim:/tb_loader/dut/load_trigger
add wave -position end  sim:/tb_loader/dut/load_num
add wave -position end  sim:/tb_loader/dut/load_addr


run 15000000ns
wave zoom full