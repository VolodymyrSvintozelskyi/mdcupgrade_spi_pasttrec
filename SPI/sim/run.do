restart -f
delete wave *
add wave -position end  sim:/pasttrec_spi_tb/CLK
add wave -position end  sim:/pasttrec_spi_tb/BUS_RX
add wave -position end  sim:/pasttrec_spi_tb/BUS_TX
add wave -position end  sim:/pasttrec_spi_tb/RST_IN
add wave -position end  sim:/pasttrec_spi_tb/SPI_CS_OUT
add wave -position end  sim:/pasttrec_spi_tb/SPI_SDI_IN
add wave -position end  sim:/pasttrec_spi_tb/SPI_SDO_OUT
add wave -position end  sim:/pasttrec_spi_tb/SPI_SCK_OUT
add wave -position end  sim:/pasttrec_spi_tb/SPI_RST_OUT

add wave -position end  sim:/pasttrec_spi_tb/dut/autoload_chipid
add wave -position end  sim:/pasttrec_spi_tb/dut/mem_addr2

add wave -position end  sim:/pasttrec_spi_tb/dut/spi_active_bunch
add wave -position end  sim:/pasttrec_spi_tb/dut/spi_active_bunch_sc
add wave -position end  sim:/pasttrec_spi_tb/dut/spi_active_bunch_autoload

add wave -position end  sim:/pasttrec_spi_tb/dut/MEMORY/ram


add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/word_length
add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/wait_cycles
add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/ctrl_reg

add wave -position end  sim:/pasttrec_spi_tb/dut/spi_fsm_state
add wave -position end  sim:/pasttrec_spi_tb/dut/sc_fsm_state

add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/BUS_DATA_OUT

add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/RESET_IN
add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/BUS_READ_IN
add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/BUS_WRITE_IN
add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/BUS_ADDR_IN
add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/BUS_DATA_IN

add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/start
add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/fsm_state

add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/RAM_BUSY
add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/RAM_OFFSET
add wave -position end  sim:/pasttrec_spi_tb/dut/SPI_INTERFACE/RAM_DATA

add wave -position end  sim:/pasttrec_spi_tb/dut/load_chipid
add wave -position end  sim:/pasttrec_spi_tb/dut/load_trigger
add wave -position end  sim:/pasttrec_spi_tb/dut/load_num
add wave -position end  sim:/pasttrec_spi_tb/dut/load_addr
add wave -position end  sim:/pasttrec_spi_tb/dut/load_past_id

run 15000000ns
wave zoom full