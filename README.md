# mdcupgrade_spi_pasttrec

Top level module for SPI communication with PASTTREC chips: 

> SPI/code/loader.vhd

#### Hierarchy 

* loader.vhd
  + *MEMORY*: 			**ram_dp_preset.vhd**
  + *SPI_INTERFACE*:    **spi_ltc2600.vhd**                   - from trbnet library.              

#### Top-level module ports

| Name        | Type                          | Mode | Description                                                  |
| ----------- | ----------------------------- | ---- | ------------------------------------------------------------ |
| CLK         | std_logic                     | In   | Clock signal                                                 |
| BUS_RX      | CTRLBUS_RX                    | In   | Slow control input                                           |
| BUS_TX      | CTRLBUS_TX                    | Out  | Slow control output                                          |
| RST_IN      | std_logic                     | In   | Reset                                                        |
| SPI_CS_OUT  | std_logic_vector(15 downto 0) | Out  | SPI chip-select bus. Allow connecting up to 16 devices. Active-low. |
| SPI_SDI_IN  | std_logic_vector(15 downto 0) | In   | SPI serial data in bus. Active-low.                          |
| SPI_SDO_OUT | std_logic_vector(15 downto 0) | Out  | SPI serial data out bus. Allow connecting up to 16 devices. Active-low. |
| SPI_SCK_OUT | std_logic_vector(15 downto 0) | Out  | SPI clock out bus. Allow connecting up to 16 devices. Active-low. |
| SPI_CLR_OUT | std_logic_vector(15 downto 0) | Out  |                                                              |

#### Slow control commands

General rules:

* For every command, the module should respond with either ack or nack or unknown bit.

* The processing time of every command is not fixed and varies from 2 clock cycle periods to 20.

Protocol:

| BUS_RX.addr | Access mode | BUX_RX.data                                                  | BUX_TX.data                                                  | Description                                                  |
| ----------- | ----------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 0xA0__      | R           | -                                                            | *31..0* - content of memory cell with 8-bit  address *BUX_RX.addr(7 downto 0)*. | Memory read                                                  |
|             | W           | *31..0* - values to be written to memory cell with 8-bit address *BUX_RX.addr(7 downto 0)*. | -                                                            | Memory write                                                 |
| 0xA10_      | W           | *7..0* - address of first command in memory.                 | -                                                            | Load configuration (15 commands) into PASTTREC chip from memory with addresses from *BUX_RX.data(7 downto 0)* to *BUX_RX.data(7 downto 0) + 0xF*. |
| 0xA11_      | W           | *18..0* - command.                                           | -                                                            | Send command directly to PASTTREC chip.                      |
| 0xA12_      | W           | *15..0* - values to be written to CS register. **'1'** - device active. | -                                                            | Overwrite the content of CS register of SPI module. Used for enabling/disabling SPI devices. |

#### Files

Code:

> SPI/code

Simulation files:

> SPI/sim



#### TO DO

New slow control communication protocol:

| BUS_RX.addr                                    | Access mode | BUX_RX.data                                                  | BUX_TX.data                                                  | Description                                              |
| ---------------------------------------------- | ----------- | ------------------------------------------------------------ | ------------------------------------------------------------ | -------------------------------------------------------- |
| **0xA0** & addr[7..0]                          | R/W         | *31..0* - content to be written to memory cell *addr[7..0]*. (**only W mode**) | *31..0* - content of memory cel  *addr[7..0*]. In a case of W mode - new content of memory cell. | Memory access                                            |
| **0xA1** & "000" & addr[4..0]                  | R/W         | *31..0* - content to be written to SPI register *addr[4..0]*. (**only W mode**) | *31..0* - content of SPI register *addr[4..0*]. (**only R mode**) | SPI module registers access.                             |
| **0xA2** & "00" & chip_id[1..0] & reg_no[3..0] | R/W         | *7..0* - content to be written to PASTTREC register *reg_no[3..0]*. (**only W mode**). | *31..0* - content of PASTTREC register *reg_no[3..0*]. In a case of W mode - new content of register. | PASTTREC chip registers access.                          |
| **0xAA** & chip_id[1..0] & cmd_id[5..0]        | W           | See PASTTREC commands table.                                 | See PASTTREC commands table.                                 | Execute a command for a PASTTREC chip with chip_id[1..0] |

PASTTREC commands table:

| cmd_id[5..0] | BUS_RX.data                                                  | BUX_TX.data | Description                                                  |
| ------------ | ------------------------------------------------------------ | ----------- | ------------------------------------------------------------ |
| 0b000000     | -                                                            | -           | Reset all settings in PASTTREC.                              |
| 0b000001     | *7..0* - address of first command in memory.<br>*15..8* - address of last command in memory (included).<br>**Not more than 15 commands per operation!** | -           | Send a set of commands to PASTTREC from memory. Command's form:<br>Header[3..0] \| Address[1..0] \| R/W \| RegNo[3..0] \| RegData[7..0] |
| 0b000010     | *7..0* - address of first command in memory.<br/>*15..8* - address of last command in memory (included).<br/>**Not more than 15 commands per operation!** | -           | Set a default set of commands for PASTTREC chip. Will be loaded from memory automatically during power on. |
