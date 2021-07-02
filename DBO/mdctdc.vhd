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

entity mdctdc is
  port(
    CLK      : in std_logic;
    CLK_TDC  : in std_logic;
    TRG      : in std_logic;           --Reference Time

    GPIO : inout std_logic_vector(3 downto 0); --0: Serdes out, 1: Serdes in, 2,3: trigger output 0+1
    LVDS : in    std_logic_vector(1 downto 0);
    
    OUTP : in  std_logic_vector(31 downto 0);
    TEST : out std_logic_vector(3 downto 0);
    INJ  : out std_logic_vector(3 downto 0);
    PTEN : out std_logic_vector(2 downto 1);

    RSTN  : out std_logic_vector(2 downto 1);
    MISO  : in  std_logic_vector(2 downto 1);
    MOSI  : out std_logic_vector(2 downto 1);
    SCK   : out std_logic_vector(2 downto 1);
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

    --LED
    LED            : out   std_logic_vector(2 downto 0)
    
    --Other Connectors
    );


  attribute syn_useioff               : boolean;
  attribute syn_useioff of FLASH_CS   : signal is true;
  attribute syn_useioff of FLASH_SCLK : signal is true;
  attribute syn_useioff of FLASH_MOSI : signal is true;
  attribute syn_useioff of FLASH_MISO : signal is true;


end entity;

architecture arch of mdctdc is
  attribute syn_keep     : boolean;
  attribute syn_preserve : boolean;

  signal clk_sys, clk_full, clk_full_osc : std_logic;
  signal GSR_N                           : std_logic;
  signal reset_i                         : std_logic;
  signal clear_i                         : std_logic;

  --Media Interface
  signal med2int                     : med2int_array_t(0 to 0);
  signal int2med                     : int2med_array_t(0 to 0);
  signal med_stat_debug              : std_logic_vector (1*64-1 downto 0);
  signal additional_reg              : std_logic_vector ( 31 downto 0);
  

  signal readout_rx                  : READOUT_RX;
  signal readout_tx                  : readout_tx_array_t(0 to 0);

  signal ctrlbus_tx, bustdc_tx, bussci_tx, bustools_tx, bustc_tx, bus_master_in  : CTRLBUS_TX;
  signal ctrlbus_rx, bustdc_rx, bussci_rx, bustools_rx, bustc_rx, bus_master_out : CTRLBUS_RX;

  signal common_stat_reg : std_logic_vector(std_COMSTATREG*32-1 downto 0) := (others => '0');
  signal common_ctrl_reg : std_logic_vector(std_COMCTRLREG*32-1 downto 0);

  signal sed_error_i       : std_logic;
  signal bus_master_active : std_logic;

  signal timer            : TIMERS;
  signal led_off          : std_logic;
  --TDC
  signal hit_in_i         : std_logic_vector(NUM_TDC_CHANNELS-1 downto 1);
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

  THE_MEDIA_INTERFACE : entity work.med_ecp5_sfp_sync
    generic map(
      SERDES_NUM    => 0,
      IS_SYNC_SLAVE => c_YES
      )
    port map(
      CLK_REF_FULL      => clk_full_osc,  --med2int(0).clk_full,
      CLK_INTERNAL_FULL => clk_full_osc,
      SYSCLK            => clk_sys,
      RESET             => reset_i,
      CLEAR             => clear_i,
      --Internal Connection
      MEDIA_MED2INT     => med2int(0),
      MEDIA_INT2MED     => int2med(0),

      --Sync operation
      RX_DLM      => open,
      RX_DLM_WORD => open,
      TX_DLM      => open,
      TX_DLM_WORD => open,

      --SFP Connection
      SD_PRSNT_N_IN  => GPIO(0),
      SD_LOS_IN      => GPIO(0),
      SD_TXDIS_OUT   => GPIO(1),
      --Control Interface
      BUS_RX        => bussci_rx,
      BUS_TX        => bussci_tx,
      -- Status and control port
      STAT_DEBUG    => med_stat_debug(63 downto 0),
      CTRL_DEBUG    => open
      );

---------------------------------------------------------------------------
-- Endpoint
---------------------------------------------------------------------------
  THE_ENDPOINT : entity work.trb_net16_endpoint_hades_full_handler_record
    generic map (
      ADDRESS_MASK              => x"FFFF",
      BROADCAST_BITMASK         => x"FF",
      REGIO_INIT_ENDPOINT_ID    => x"0001",
      REGIO_USE_1WIRE_INTERFACE => c_I2C,
      TIMING_TRIGGER_RAW        => c_YES,
      --Configure data handler
      DATA_INTERFACE_NUMBER     => 1,
      DATA_BUFFER_DEPTH         => EVENT_BUFFER_SIZE,
      DATA_BUFFER_WIDTH         => 32,
      DATA_BUFFER_FULL_THRESH   => 2**EVENT_BUFFER_SIZE-EVENT_MAX_SIZE,
      TRG_RELEASE_AFTER_DATA    => c_YES,
      HEADER_BUFFER_DEPTH       => 9,
      HEADER_BUFFER_FULL_THRESH => 2**9-16
      )

    port map(
      --  Misc
      CLK    => clk_sys,
      RESET  => reset_i,
      CLK_EN => '1',

      --  Media direction port
      MEDIA_MED2INT => med2int(0),
      MEDIA_INT2MED => int2med(0),

      --Timing trigger in
      TRG_TIMING_TRG_RECEIVED_IN => TRG,

      READOUT_RX => readout_rx,
      READOUT_TX => readout_tx,

      --Slow Control Port
      REGIO_COMMON_STAT_REG_IN  => common_stat_reg,  --0x00
      REGIO_COMMON_CTRL_REG_OUT => common_ctrl_reg,  --0x20
      BUS_RX                    => ctrlbus_rx,
      BUS_TX                    => ctrlbus_tx,
      BUS_MASTER_IN             => bus_master_in,
      BUS_MASTER_OUT            => bus_master_out,
      BUS_MASTER_ACTIVE         => bus_master_active,

      ONEWIRE_INOUT => open,
      I2C_SCL       => I2C_SCL,
      I2C_SDA       => I2C_SDA,
      --Timing registers
      TIMERS_OUT    => timer
      );

---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------


  THE_BUS_HANDLER : entity work.trb_net16_regio_bus_handler_record
    generic map(
      PORT_NUMBER      => 3,
      PORT_ADDRESSES   => (0 => x"d000", 1 => x"b000", 2 => x"c000", others => x"0000"),
      PORT_ADDR_MASK   => (0 => 12, 1 => 9,  2 => 12, others => 0),
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
      BUS_TX(0) => bustools_tx,
      BUS_TX(1) => bussci_tx,
      BUS_TX(2) => bustdc_tx,

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
      SPI_CS_OUT(1 downto 0)        => RSTN,
      SPI_MOSI_OUT(1 downto 0)      => MOSI,
      SPI_MISO_IN(1 downto 0)       => MISO,
      SPI_CLK_OUT(1 downto 0)       => SCK,
      --Header
      HEADER_IO         => open,
      ADDITIONAL_REG    => additional_reg,

      --LCD
      LCD_DATA_IN       => (others => '0'),
      --ADC
      ADC_CS            => open,
      ADC_MOSI          => open,
      ADC_MISO          => open,
      ADC_CLK           => open,
      --Trigger & Monitor 
      MONITOR_INPUTS    => monitor_inputs_i,
      TRIG_GEN_INPUTS   => trigger_inputs_i,
      TRIG_GEN_OUTPUTS(1 downto 0)  => GPIO(3 downto 2),
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
  monitor_inputs_i <= OUTP(MONITOR_INPUT_NUM-1 downto 0);
  trigger_inputs_i <= OUTP(TRIG_GEN_INPUT_NUM-1 downto 0);
  hit_in_i         <= OUTP(NUM_TDC_CHANNELS-2 downto 0);
  
---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------
  LED(0) <= (med2int(0).stat_op(10) or med2int(0).stat_op(11)) and not led_off;
  LED(1) <= med2int(0).stat_op(9) and not led_off;
  LED(2) <= FLASH_SELECT and not led_off;

  
--------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
  PTEN <= "11";
  INJ  <= additional_reg(19 downto 16); --"0000";
  TEST <= additional_reg(27 downto 24); --"0000";
  
  
-------------------------------------------------------------------------------
-- TDC
-------------------------------------------------------------------------------
-- THE_TDC : entity work.TDC_FF
--   generic map(
--     CHANNELS => 17
--     )
--   port map(
--     CLK        => CLK_125,
--     SYSCLK     => clk_sys,
--     RESET_IN   => reset_i,
--     SIGNAL_IN  => INP(16 downto 0),
--     
--     BUS_RX => bustdc_rx,
--     BUS_TX => bustdc_tx,
-- 
--     READOUT_RX => readout_rx,
--     READOUT_TX => readout_tx  
--     
--     );
-- 
-- 


-------------------------------------------------------------------------------
-- No trigger/data endpoint included
-------------------------------------------------------------------------------
readout_tx(0).data_finished <= '1';
readout_tx(0).data_write    <= '0';
readout_tx(0).busy_release  <= '1';    
  
end architecture;



