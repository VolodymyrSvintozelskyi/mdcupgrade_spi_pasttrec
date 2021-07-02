library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.version.all;
use work.config.all;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.med_sync_define.all;
use work.trb_net16_hub_func.all;

entity mdcoep is
  port(
    CLK      : in std_logic;
    TRG      : in std_logic;

    GPIO : inout std_logic_vector(11 downto 0); --0: Serdes in, 1: Serdes out, 2,3: trigger input 0+1
    LVDS : out   std_logic_vector(5 downto 0);
    
    --Flash, Reload
    FLASH_SCLK   : out   std_logic;
    FLASH_CS     : out   std_logic;
    FLASH_MOSI   : out   std_logic;
    FLASH_MISO   : in    std_logic;
    FLASH_HOLD   : out   std_logic;
    FLASH_WP     : out   std_logic;
    FLASH_SELECT : in    std_logic;
    FLASH_OVERRIDE : out std_logic;
    PROGRAMN     : out   std_logic;
    
    --I2C
    I2C_SDA      : inout std_logic;
    I2C_SCL      : inout std_logic;
    TMP_ALERT    : in    std_logic;

    SFP_LOS      : in    std_logic;
    SFP_TX_DIS   : out   std_logic;
    SFP_MOD0     : in    std_logic;
    
    ADC_MISO     : in    std_logic;
    ADC_MOSI     : out   std_logic;
    ADC_SCK      : out   std_logic;
    ADC_CS       : out   std_logic;
    
    --LED
    LED            : out   std_logic_vector(7 downto 0)
    
    --Other Connectors
    );


  attribute syn_useioff               : boolean;
  attribute syn_useioff of FLASH_CS   : signal is true;
  attribute syn_useioff of FLASH_SCLK : signal is true;
  attribute syn_useioff of FLASH_MOSI : signal is true;
  attribute syn_useioff of FLASH_MISO : signal is true;


end entity;

architecture arch of mdcoep is
  constant INTERFACE_NUM : integer := 3;


  attribute syn_keep     : boolean;
  attribute syn_preserve : boolean;
  
  signal clk_sys, clk_full, clk_full_osc : std_logic;
  signal GSR_N                           : std_logic;
  signal reset_i                         : std_logic;
  signal clear_i                         : std_logic;

  --Media Interface
  signal med2int                     : med2int_array_t(0 to INTERFACE_NUM-1);
  signal int2med                     : int2med_array_t(0 to INTERFACE_NUM-1);
  signal med_stat_debug              : std_logic_vector (1*64-1 downto 0);
  signal additional_reg              : std_logic_vector ( 31 downto 0);

  signal med_dataready_out    : std_logic_vector (INTERFACE_NUM-1 downto 0);
  signal med_data_out         : std_logic_vector (INTERFACE_NUM*c_DATA_WIDTH-1 downto 0);
  signal med_packet_num_out   : std_logic_vector (INTERFACE_NUM*c_NUM_WIDTH-1 downto 0);
  signal med_read_in          : std_logic_vector (INTERFACE_NUM-1 downto 0);
  signal med_dataready_in     : std_logic_vector (INTERFACE_NUM-1 downto 0);
  signal med_data_in          : std_logic_vector (INTERFACE_NUM*c_DATA_WIDTH-1 downto 0);
  signal med_packet_num_in    : std_logic_vector (INTERFACE_NUM*c_NUM_WIDTH-1 downto 0);
  signal med_read_out         : std_logic_vector (INTERFACE_NUM-1 downto 0);
  signal med_stat_op          : std_logic_vector (INTERFACE_NUM*16-1 downto 0);
  signal med_ctrl_op          : std_logic_vector (INTERFACE_NUM*16-1 downto 0);  
  signal rdack, wrack         : std_logic;  
  
  signal readout_rx                  : READOUT_RX;
  signal readout_tx                  : readout_tx_array_t(0 to 0);

  signal ctrlbus_tx, bustdc_tx, bussci_tx, bussci2_tx, bustools_tx, bustc_tx, bus_master_in  : CTRLBUS_TX;
  signal ctrlbus_rx, bustdc_rx, bussci_rx, bussci2_rx, bustools_rx, bustc_rx, bus_master_out : CTRLBUS_RX;

  signal common_stat_reg : std_logic_vector(std_COMSTATREG*32-1 downto 0) := (others => '0');
  signal common_ctrl_reg : std_logic_vector(std_COMCTRLREG*32-1 downto 0);

  signal sed_error_i       : std_logic;
  signal bus_master_active : std_logic;

  signal timer            : TIMERS;
  signal led_off          : std_logic;

  signal monitor_inputs_i : std_logic_vector(MONITOR_INPUT_NUM-1 downto 0);
  signal trigger_inputs_i : std_logic_vector(TRIG_GEN_INPUT_NUM-1 downto 0);  
begin

---------------------------------------------------------------------------
-- Clock & Reset Handling
---------------------------------------------------------------------------
  THE_CLOCK_RESET : entity work.clock_reset_handler
    port map(
      CLOCK_IN       => CLK,
      RESET_FROM_NET => med2int(0).stat_op(13),
      SEND_RESET_IN  => med2int(0).stat_op(15),

      BUS_RX => bustc_rx,
      BUS_TX => bustc_tx,

      RESET_OUT => reset_i,
      CLEAR_OUT => clear_i,
      GSR_OUT   => GSR_N,

      REF_CLK_OUT => clk_full,
      SYS_CLK_OUT => clk_sys,
      RAW_CLK_OUT => clk_full_osc,

      DEBUG_OUT => open
      );


---------------------------------------------------------------------------
-- TrbNet Uplink
---------------------------------------------------------------------------

  THE_MEDIA_INTERFACE : entity work.med_ecp5_sfp_sync_2
    generic map(

      IS_SYNC_SLAVE => (c_YES,c_NO)
      )
    port map(
      CLK_REF_FULL      => clk_full_osc,  --med2int(0).clk_full,
      CLK_INTERNAL_FULL => clk_full_osc,
      SYSCLK            => clk_sys,
      RESET             => reset_i,
      CLEAR             => clear_i,
      --Internal Connection
      MEDIA_MED2INT     => med2int(0 to 1),
      MEDIA_INT2MED     => int2med(0 to 1),

      --Sync operation
--       RX_DLM      => open,
--       RX_DLM_WORD => open,
--       TX_DLM      => open,
--       TX_DLM_WORD => open,

      --SFP Connection
      SD_PRSNT_N_IN(0)  => SFP_MOD0,
      SD_LOS_IN(0)      => SFP_LOS,
      SD_TXDIS_OUT(0)   => SFP_TX_DIS,
      SD_PRSNT_N_IN(1)  => GPIO(1),
      SD_LOS_IN(1)      => GPIO(1),
      SD_TXDIS_OUT(1)   => GPIO(0),
      --Control Interface
      BUS_RX        => bussci_rx,
      BUS_TX        => bussci_tx
      -- Status and control port
--       STAT_DEBUG    => open, --med_stat_debug(63 downto 0),
--       CTRL_DEBUG    => open
      );

---------------------------------------------------------------------------
-- Second TrbNet Downlink
---------------------------------------------------------------------------
  THE_DOWN_INTERFACE_2 : entity work.med_ecp5_sfp_sync
    generic map(
      SERDES_NUM    => 2,
      IS_SYNC_SLAVE => c_NO
      )
    port map(
      CLK_REF_FULL      => clk_full_osc,  --med2int(0).clk_full,
      CLK_INTERNAL_FULL => clk_full_osc,
      SYSCLK            => clk_sys,
      RESET             => reset_i,
      CLEAR             => clear_i,
      --Internal Connection
      MEDIA_MED2INT     => med2int(2),
      MEDIA_INT2MED     => int2med(2),

      --Sync operation
      RX_DLM      => open,
      RX_DLM_WORD => open,
      TX_DLM      => open,
      TX_DLM_WORD => open,

      --SFP Connection
      SD_PRSNT_N_IN  => GPIO(5),
      SD_LOS_IN      => GPIO(5),
      SD_TXDIS_OUT   => GPIO(4),
      --Control Interface
      BUS_RX        => bussci2_rx,
      BUS_TX        => bussci2_tx,
      -- Status and control port
      STAT_DEBUG    => open, --med_stat_debug(63 downto 0),
      CTRL_DEBUG    => open
      );      
      
---------------------------------------------------------------------------
-- Endpoint
---------------------------------------------------------------------------
--   THE_ENDPOINT : entity work.trb_net16_endpoint_hades_full_handler_record
--     generic map (
--       ADDRESS_MASK              => x"FFFF",
--       BROADCAST_BITMASK         => x"FF",
--       REGIO_INIT_ENDPOINT_ID    => x"0001",
--       REGIO_USE_1WIRE_INTERFACE => c_I2C,
--       TIMING_TRIGGER_RAW        => c_YES,
--       --Configure data handler
--       DATA_INTERFACE_NUMBER     => 1,
--       DATA_BUFFER_DEPTH         => EVENT_BUFFER_SIZE,
--       DATA_BUFFER_WIDTH         => 32,
--       DATA_BUFFER_FULL_THRESH   => 2**EVENT_BUFFER_SIZE-EVENT_MAX_SIZE,
--       TRG_RELEASE_AFTER_DATA    => c_YES,
--       HEADER_BUFFER_DEPTH       => 9,
--       HEADER_BUFFER_FULL_THRESH => 2**9-16
--       )
-- 
--     port map(
--       --  Misc
--       CLK    => clk_sys,
--       RESET  => reset_i,
--       CLK_EN => '1',
-- 
--       --  Media direction port
--       MEDIA_MED2INT => med2int(0),
--       MEDIA_INT2MED => int2med(0),
-- 
--       --Timing trigger in
--       TRG_TIMING_TRG_RECEIVED_IN => TRG,
-- 
--       READOUT_RX => readout_rx,
--       READOUT_TX => readout_tx,
-- 
--       --Slow Control Port
--       REGIO_COMMON_STAT_REG_IN  => common_stat_reg,  --0x00
--       REGIO_COMMON_CTRL_REG_OUT => common_ctrl_reg,  --0x20
--       BUS_RX                    => ctrlbus_rx,
--       BUS_TX                    => ctrlbus_tx,
--       BUS_MASTER_IN             => bus_master_in,
--       BUS_MASTER_OUT            => bus_master_out,
--       BUS_MASTER_ACTIVE         => bus_master_active,
-- 
--       ONEWIRE_INOUT => open,
--       I2C_SCL       => I2C_SCL,
--       I2C_SDA       => I2C_SDA,
--       --Timing registers
--       TIMERS_OUT    => timer
--       );
-- 
--       

  THE_HUB : entity work.trb_net16_hub_base
    generic map( 
      HUB_USED_CHANNELS   => (1,1,0,1),
      INIT_ADDRESS        => INIT_ADDRESS,
      MII_NUMBER          => INTERFACE_NUM,
      MII_IS_UPLINK       => (1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
      MII_IS_DOWNLINK     => (0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0),
      MII_IS_UPLINK_ONLY  => (1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
      USE_ONEWIRE         => c_I2C,
      HARDWARE_VERSION    => HARDWARE_INFO,
      INCLUDED_FEATURES   => INCLUDED_FEATURES,
      INIT_ENDPOINT_ID    => x"0001",
      CLOCK_FREQUENCY     => CLOCK_FREQUENCY,
      BROADCAST_SPECIAL_ADDR => BROADCAST_SPECIAL_ADDR,
      COMPILE_TIME        => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32))
      )
    port map (
      CLK    => clk_sys,
      RESET  => reset_i,
      CLK_EN => '1',

      --Media interfacces
      MED_DATAREADY_OUT(INTERFACE_NUM*1-1 downto 0)   => med_dataready_out(INTERFACE_NUM*1-1 downto 0),
      MED_DATA_OUT(INTERFACE_NUM*16-1 downto 0)       => med_data_out(INTERFACE_NUM*16-1 downto 0),
      MED_PACKET_NUM_OUT(INTERFACE_NUM*3-1 downto 0)  => med_packet_num_out(INTERFACE_NUM*3-1 downto 0),
      MED_READ_IN(INTERFACE_NUM*1-1 downto 0)         => med_read_in(INTERFACE_NUM*1-1 downto 0),
      MED_DATAREADY_IN(INTERFACE_NUM*1-1 downto 0)    => med_dataready_in(INTERFACE_NUM*1-1 downto 0),
      MED_DATA_IN(INTERFACE_NUM*16-1 downto 0)        => med_data_in(INTERFACE_NUM*16-1 downto 0),
      MED_PACKET_NUM_IN(INTERFACE_NUM*3-1 downto 0)   => med_packet_num_in(INTERFACE_NUM*3-1 downto 0),
      MED_READ_OUT(INTERFACE_NUM*1-1 downto 0)        => med_read_out(INTERFACE_NUM*1-1 downto 0),
      MED_STAT_OP(INTERFACE_NUM*16-1 downto 0)        => med_stat_op(INTERFACE_NUM*16-1 downto 0),
      MED_CTRL_OP(INTERFACE_NUM*16-1 downto 0)        => med_ctrl_op(INTERFACE_NUM*16-1 downto 0),

      COMMON_STAT_REGS                => common_stat_reg,
      COMMON_CTRL_REGS                => common_ctrl_reg,
      MY_ADDRESS_OUT                  => open,
      --REGIO INTERFACE
      REGIO_ADDR_OUT            => ctrlbus_rx.addr,
      REGIO_READ_ENABLE_OUT     => ctrlbus_rx.read,
      REGIO_WRITE_ENABLE_OUT    => ctrlbus_rx.write,
      REGIO_DATA_OUT            => ctrlbus_rx.data,
      REGIO_DATA_IN             => ctrlbus_tx.data,
      REGIO_DATAREADY_IN        => rdack,
      REGIO_NO_MORE_DATA_IN     => ctrlbus_tx.nack,
      REGIO_WRITE_ACK_IN        => wrack,
      REGIO_UNKNOWN_ADDR_IN     => ctrlbus_tx.unknown,
      REGIO_TIMEOUT_OUT         => ctrlbus_rx.timeout,
      
      ONEWIRE                         => open,
      ONEWIRE_MONITOR_OUT             => open,
      I2C_SCL       => I2C_SCL,
      I2C_SDA       => I2C_SDA,      
      --Status ports (for debugging)
      MPLEX_CTRL            => (others => '0'),
      CTRL_DEBUG            => (others => '0'),
      STAT_DEBUG            => open
      );

  gen_media_record : for i in 0 to INTERFACE_NUM-1 generate
    med_data_in(i*16+15 downto i*16)    <= med2int(i).data;
    med_packet_num_in(i*3+2 downto i*3) <= med2int(i).packet_num;
    med_dataready_in(i)                 <= med2int(i).dataready;
    med_read_in(i)                      <= med2int(i).tx_read;
    med_stat_op(i*16+15 downto i*16)    <= med2int(i).stat_op;
    
    int2med(i).data         <= med_data_out(i*16+15 downto i*16);    
    int2med(i).packet_num   <= med_packet_num_out(i*3+2 downto i*3);
    int2med(i).dataready    <= med_dataready_out(i);
    int2med(i).ctrl_op      <= med_ctrl_op(i*16+15 downto i*16);
  end generate;      

  rdack <= ctrlbus_tx.ack or ctrlbus_tx.rack;      
  wrack <= ctrlbus_tx.ack or ctrlbus_tx.wack;      

---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------


  THE_BUS_HANDLER : entity work.trb_net16_regio_bus_handler_record
    generic map(
      PORT_NUMBER      => 4,
      PORT_ADDRESSES   => (0 => x"d000", 1 => x"b000", 2 => x"c000", 3 => x"b200", others => x"0000"),
      PORT_ADDR_MASK   => (0 => 12, 1 => 9,  2 => 12, 3 => 9, others => 0),
      PORT_MASK_ENABLE => 1
      )
    port map(
      CLK   => clk_sys,
      RESET => reset_i,

      REGIO_RX => ctrlbus_rx,
      REGIO_TX => ctrlbus_tx,

      BUS_RX(0) => bustools_rx,         --Flash, SPI, UART, ADC, SED
      BUS_RX(1) => bussci_rx,           --SCI Serdes
      BUS_RX(2) => bustdc_rx,            --Clock switch
      BUS_RX(3) => bussci2_rx,
      BUS_TX(0) => bustools_tx,
      BUS_TX(1) => bussci_tx,
      BUS_TX(2) => bustdc_tx,
      BUS_TX(3) => bussci2_tx,

      STAT_DEBUG => open
      );

---------------------------------------------------------------------------
-- Control Tools
---------------------------------------------------------------------------
  THE_TOOLS : entity work.trb3sc_tools
    port map(
      CLK   => clk_sys,
      RESET => reset_i,

      --Flash & Reload
      FLASH_CS          => FLASH_CS,
      FLASH_CLK         => FLASH_SCLK,
      FLASH_IN          => FLASH_MISO,
      FLASH_OUT         => FLASH_MOSI,
      PROGRAMN          => PROGRAMN,
      REBOOT_IN         => common_ctrl_reg(15),
      --SPI
      SPI_CS_OUT        => open,
      SPI_MOSI_OUT      => open,
      SPI_MISO_IN       => open,
      SPI_CLK_OUT       => open,
      --Header
      HEADER_IO         => open,
      ADDITIONAL_REG    => additional_reg,
      --ADC
      ADC_CS            => ADC_CS,
      ADC_MOSI          => ADC_MOSI,
      ADC_MISO          => ADC_MISO,
      ADC_CLK           => ADC_SCK,
      --Trigger & Monitor 
      MONITOR_INPUTS    => monitor_inputs_i,
      TRIG_GEN_INPUTS   => trigger_inputs_i,
      TRIG_GEN_OUTPUTS(1 downto 0)  => open, --GPIO(3 downto 2),
      --SED
      SED_ERROR_OUT     => sed_error_i,
      --Slowcontrol
      BUS_RX            => bustools_rx,
      BUS_TX            => bustools_tx,
      --Control master for default settings
      BUS_MASTER_IN     => bus_master_in,
      BUS_MASTER_OUT    => bus_master_out,
      BUS_MASTER_ACTIVE => bus_master_active,
      DEBUG_OUT         => open
      );

  FLASH_HOLD <= '1';
  FLASH_WP   <= '1';

  led_off        <= additional_reg(0);
  FLASH_OVERRIDE <= not additional_reg(1);
  
---------------------------------------------------------------------------
-- I/O
---------------------------------------------------------------------------

  
---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED(0) <= (med2int(0).stat_op(10) or med2int(0).stat_op(11)) and not led_off;
  LED(1) <= med2int(0).stat_op(9) and not led_off;
  LED(2) <= FLASH_SELECT and not led_off;
  
  LED(3) <= (med2int(1).stat_op(10) or med2int(1).stat_op(11)) and not led_off;
  LED(4) <= med2int(1).stat_op(9) and not led_off;

-------------------------------------------------------------------------------
-- No trigger/data endpoint included
-------------------------------------------------------------------------------
-- readout_tx(0).data_finished <= '1';
-- readout_tx(0).data_write    <= '0';
-- readout_tx(0).busy_release  <= '1';    
  
end architecture;



