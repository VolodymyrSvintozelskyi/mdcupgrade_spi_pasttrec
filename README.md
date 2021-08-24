# mdcupgrade_spi_pasttrec

Top level module for SPI communication with PASTTREC chips: 

> SPI/code/loader.vhd

#### Hierarchy 

* loader.vhd
  + *MEMORY*: 			**ram_dp_preset.vhd**
  + *SPI_INTERFACE*:    **spi_ltc2600_siml.vhd**   - simplified version of spi_ltc2600.vhd                               

#### Top-level module ports

| Name        | Type       | Mode | Description                         |
| ----------- | ---------- | ---- | ----------------------------------- |
| CLK         | std_logic  | In   | Clock signal                        |
| BUS_RX      | CTRLBUS_RX | In   | Slow control input                  |
| BUS_TX      | CTRLBUS_TX | Out  | Slow control output                 |
| RST_IN      | std_logic  | In   | Reset                               |
| SPI_CS_OUT  | std_logic  | Out  | SPI chip-select signal. Active-low. |
| SPI_SDI_IN  | std_logic  | In   | SPI serial data in signal.          |
| SPI_SDO_OUT | std_logic  | Out  | SPI serial data out signal.         |
| SPI_SCK_OUT | std_logic  | Out  | SPI clock out signal.               |
| SPI_RST_OUT | std_logic  | Out  | SPI reset signal. Active-low.       |

#### Memory

Whole system shares one common memory, implemented in ram_dp_preset.vhd. For test purposes, it's content is loaded from file during compilation.

| Address     | Content                                                      | Description                                                  |
| ----------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 0x00        | 0x0000                                                       | Zero word. Can't be overided.                                |
| 0x01        | 0x\*\*\*\*                                                   | Buffer for command transmitting via SPI. Forbidden to write during transmitting. **Not for end user** |
| 0x02        | **PASTTREC 01**<br>*30* - autoload enable<br>*29..24* - number of autoload commands (unsigned)<br>*23..16* - first command address<br>**PASTTREC 00**<br>*14* - autoload enable<br/>*13..8* - number of autoload commands (unsigned)<br/>*7..0* - first command address | Autostart settings for PASTTREC 00 & PASTTREC 01             |
| 0x03        | **PASTTREC 11**<br/>*30* - autoload enable<br/>*29..24* - number of autoload commands (unsigned)<br/>*23..16* - first command address<br/>**PASTTREC 10**<br/>*14* - autoload enable<br/>*13..8* - number of autoload commands (unsigned)<br/>*7..0* - first command address | Autostart settings for PASTTREC 10 & PASTTREC 11             |
| 0x04 - 0xFF | 0x\*\*\*\*                                                   | Free memory. Can be used by end user.                        |

#### Slow control commands

General rules:

* For every command, the module should respond with either ack or nack or unknown bit not later than 5 clock cycles.

* If second commands arrives earlier than module send response for first one, it'll be ignored.

Protocol:

| BUS_RX.addr                                       | Access mode | BUX_RX.data (only in W mode)                                 | BUX_TX.data                                                  | Description                                                  |
| ------------------------------------------------- | ----------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| **0xA0\*\***                                      | -----       | ------------------------                                     | ----------------                                             | **Memory access**                                            |
| **0xA0** & addr[7..0]                             | R/W         | *31..0* - content to be written to memory cell *addr[7..0]*. | *31..0* - content of memory cell *addr[7..0*].               | Memory access<br>**Access to *0xA001* is forbidden during SPI transmitting.** |
| **0xA1\*\***                                      | -----       | ------------------------                                     | ----------------                                             | **SPI module access**                                        |
| **0xA100**                                        | W           | *31* - reset bit. High - active.                             | -                                                            | Set SPI module fsm reset high.<br>*It's bit 31 of ctrl_reg register* |
| **0xA101**                                        | R/W         | *31..0* - content to be written to SPI module ctrl_reg.<br>*Bits 6 and 7 can be high if an0xA001d only if at least one of bits 5..0 is high.* | *31..0* - content of SPI module ctrl register                | Full access to SPI control register.                         |
| **0xA102**                                        | R/W         | *5* - override sdo <br>*4* - override sck <br/>*3* - override cs <br/>*2* - invert sdo <br/>*1* - invert sck <br/>*0* - invert cs | *5* - override sdo <br/>*4* - override sck <br/>*3* - override cs <br/>*2* - invert sdo <br/>*1* - invert sck <br/>*0* - invert cs | Access to override/invert register.<br>*It's bits 13..8 of ctrl_reg register* |
| **0xA103**                                        | R/W         | *15..6* - wait cycles (unsigned, def = 7).<br>*5..0* - word length (unsigned, def = 19) | *15..6* - wait cycles (unsigned, def = 7).<br/>*5..0* - word length (unsigned, def = 19) | Access to wait cycles/word length register.<br>*It's bits 29..14 of ctrl_reg register* |
| **0xA10A**                                        | W           | *7* - block bit. If high SPI module will block after transaction.<br>*6* - start bit. If high SPI module will begin transmitting.<br>*5..0* - number of words to be transmitted. Required to be non zero for transmitting (unsigned) | -                                                            | Transmit data direct from memory. <br>**Not for end user.**  |
| **0xA10B**                                        | R           | -                                                            | *31..0* - content of SPI readback register.                  | Receive data from SPI. Disable SPI blocking.<br>**Not tested! Data flow isn't implemented!** |
| **0xA2\*\***                                      | -----       | ------------------------                                     | ----------------                                             | **PASTTREC access.**                                         |
| **0xA2** & "00" & chip_id[1..0] & reg_no[3..0]    | W           | *7..0* - content to be written to PASTTREC register *reg_no[3..0]*. | -                                                            | PASTTREC chip registers access.                              |
| **0xAA\*\***                                      | -----       | ------------------------                                     | ----------------                                             | **Complex operations.**                                      |
| **0xAA00**                                        | W           | -                                                            | -                                                            | Whole system reset.<br>Execute reset & autostart sequence of PASTTREC. |
| **0xAA** & all_bit[1] & chip_id[1..0] & **00001** | W           | *13..8* - number of commands in set. (unsigned, should be at least 1)<br>*7..0* - address of first command in memory. | -                                                            | Load set of commands from memory to PASTTREC  chip.<br>If all_bit[1] is high, set will be loaded to all PASTTREC chips. In this case, bits 14..13 of command will be overwritten with actual chip_id.<br>If all_bit[1] is low, set will be loaded only to PASTTREC with chip id = chip_id[1..0]. |

#### Reset & autostart sequence

During reset sequence firstly the module will send two words with low and high RST_OUT values for resetting all PASTTREC chips.

![image](https://i.ibb.co/7kqqP1n/reset.png)

After this, the module will begin transmitting the configuration commands for every PASTTREC chip one by one, first for chip_id 00. It can be configured with memory registers 0x02 and 0x03. 

#### Files

Code:

> SPI/code/*

Simulation files:

> SPI/sim/*

