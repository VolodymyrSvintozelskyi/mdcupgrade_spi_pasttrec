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

entity trb5sc_mdctdc is
  port(
    CLK_200  : in std_logic;
    CLK_125  : in std_logic;
    CLK_EXT  : in std_logic;
    
    TRIG_IN_BACKPL : in std_logic;           --Reference Time
    TRIG_IN_RJ45   : in std_logic;           --Reference Time
    IN_SELECT_EXT_CLOCK : in std_logic;

    SPARE     : out   std_logic_vector(1 downto 0); -- trigger output 2+3
    BACK_GPIO : inout std_logic_vector(3 downto 0); --0: Serdes out, 1: Serdes in, 2,3: trigger output 0+1
    
    SFP_TX_DIS : out std_logic;
    SFP_LOS    : in  std_logic;
    SFP_MOD_0  : in  std_logic;
    
    --AddOn
--     FE_GPIO    : inout std_logic_vector(11 downto 0);
--     FE_CLK     : out   std_logic_vector( 2 downto 1);
--     FE_DIFF    : inout std_logic_vector(63 downto 0);
    INP : in std_logic_vector(63 downto 0);

    CS    : out std_logic_vector(4 downto 1);
    MISO  : in  std_logic_vector(4 downto 1);
    MOSI  : out std_logic;
    SCK   : out std_logic;
    
    --ADC
    ADC_SCLK     : out   std_logic;
    ADC_NCS      : out   std_logic;
    ADC_MOSI     : out   std_logic;
    ADC_MISO     : in    std_logic;
    --Flash, Reload
    FLASH_SCLK   : out   std_logic;
    FLASH_NCS    : out   std_logic;
    FLASH_MOSI   : out   std_logic;
    FLASH_MISO   : in    std_logic;
    FLASH_HOLD   : out   std_logic;
    FLASH_WP     : out   std_logic;
    PROGRAMN     : out   std_logic;
    --I2C
    I2C_SDA      : inout std_logic;
    I2C_SCL      : inout std_logic;
    TMP_ALERT    : in    std_logic;

    --LED
    LED            : out   std_logic_vector(8 downto 1);
    LED_SFP_YELLOW : out   std_logic;
    LED_SFP_GREEN  : out   std_logic;
    LED_SFP_RED    : out   std_logic;
    LED_RJ_GREEN   : out   std_logic_vector(1 downto 0);
    LED_RJ_RED     : out   std_logic_vector(1 downto 0);
    LED_EXT_CLOCK  : out   std_logic;
    
    --Other Connectors
    TEST    : inout std_logic_vector(14 downto 1);
    HDR_IO  : inout std_logic_vector(15 downto 0)
    );


  attribute syn_useioff              : boolean;
  attribute syn_useioff of FLASH_NCS  : signal is true;
  attribute syn_useioff of FLASH_SCLK : signal is true;
  attribute syn_useioff of FLASH_MOSI : signal is true;
  attribute syn_useioff of FLASH_MISO : signal is true;


end entity;

architecture arch of trb5sc_mdctdc is
  attribute syn_keep     : boolean;
  attribute syn_preserve : boolean;

  signal clk_sys, clk_full, clk_full_osc, clk_cal : std_logic;
  signal GSR_N                           : std_logic;
  signal reset_i                         : std_logic;
  signal clear_i                         : std_logic;
  signal trigger_in_i                    : std_logic;

  signal debug_clock_reset : std_logic_vector(31 downto 0);
  signal debug_tools       : std_logic_vector(31 downto 0);

  --Media Interface
  signal med2int                     : med2int_array_t(0 to 0);
  signal int2med                     : int2med_array_t(0 to 0);
  signal med_stat_debug              : std_logic_vector (1*64-1 downto 0);
  signal sfp_los_i, sfp_txdis_i, sfp_prsnt_i : std_logic;
  

  signal readout_rx                  : READOUT_RX;
  signal readout_tx                  : readout_tx_array_t(0 to 0);

  signal ctrlbus_tx, bustdc_tx, bussci_tx, bustools_tx, bustc_tx, busthresh_tx, bus_master_in  : CTRLBUS_TX;
  signal ctrlbus_rx, bustdc_rx, bussci_rx, bustools_rx, bustc_rx, busthresh_rx, bus_master_out : CTRLBUS_RX;

  signal common_stat_reg : std_logic_vector(std_COMSTATREG*32-1 downto 0) := (others => '0');
  signal common_ctrl_reg : std_logic_vector(std_COMCTRLREG*32-1 downto 0);

  signal sed_error_i       : std_logic;
  signal clock_select      : std_logic;
  signal bus_master_active : std_logic;
  signal flash_ncs_i       : std_logic;

  signal spi_cs, spi_mosi, spi_miso, spi_clk : std_logic_vector(15 downto 0);
  signal header_io_i      : std_logic_vector(10 downto 1);
  signal timer            : TIMERS;
  signal led_off          : std_logic;
  --TDC
  signal hit_in_i         : std_logic_vector(NUM_TDC_CHANNELS-1 downto 1);
  signal monitor_inputs_i : std_logic_vector(MONITOR_INPUT_NUM-1 downto 0);
  signal trigger_inputs_i : std_logic_vector(TRIG_GEN_INPUT_NUM-1 downto 0);


  attribute syn_keep of GSR_N     : signal is true;
  attribute syn_preserve of GSR_N : signal is true;  
  
  signal link_stat_in_reg : std_logic;

  signal tdc_data : std_logic_vector(31 downto 0);
  signal tdc_read, tdc_empty : std_logic;
  
begin

trigger_in_i <= (TRIG_IN_BACKPL and IN_SELECT_EXT_CLOCK) or (TRIG_IN_RJ45 and not IN_SELECT_EXT_CLOCK);


---------------------------------------------------------------------------
-- Clock & Reset Handling
---------------------------------------------------------------------------
  THE_CLOCK_RESET : entity work.clock_reset_handler
    port map(
      CLOCK_IN       => CLK_200,
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

      DEBUG_OUT => debug_clock_reset
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
      SD_PRSNT_N_IN  => sfp_prsnt_i,
      SD_LOS_IN      => sfp_los_i,
      SD_TXDIS_OUT   => sfp_txdis_i,
      --Control Interface
      BUS_RX        => bussci_rx,
      BUS_TX        => bussci_tx,
      -- Status and control port
      STAT_DEBUG    => med_stat_debug(63 downto 0),
      CTRL_DEBUG    => open
      );

  gen_sfp_con : if SERDES_NUM = 1 generate
    sfp_los_i   <= SFP_LOS;
    sfp_prsnt_i <= SFP_MOD_0; 
    SFP_TX_DIS  <= sfp_txdis_i;
  end generate;  
  gen_bpl_con : if SERDES_NUM = 0 generate
    sfp_los_i    <= BACK_GPIO(1);
    sfp_prsnt_i  <= BACK_GPIO(1); 
    BACK_GPIO(0) <= sfp_txdis_i;
  end generate;  
        

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
      TRG_TIMING_TRG_RECEIVED_IN => trigger_in_i,

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
      PORT_NUMBER      => 4,
      PORT_ADDRESSES   => (0 => x"d000", 1 => x"b000", 2 => x"d300", 3 => x"c000", others => x"0000"),
      PORT_ADDR_MASK   => (0 => 12, 1 => 9, 2 => 1, 3 => 12, others => 0),
      PORT_MASK_ENABLE => 1
      )
    port map(
      CLK   => clk_sys,
      RESET => reset_i,

      REGIO_RX => ctrlbus_rx,
      REGIO_TX => ctrlbus_tx,

      BUS_RX(0) => bustools_rx,         --Flash, SPI, UART, ADC, SED
      BUS_RX(1) => bussci_rx,           --SCI Serdes
      BUS_RX(2) => bustc_rx,            --Clock switch
      BUS_RX(3) => bustdc_rx,
      BUS_TX(0) => bustools_tx,
      BUS_TX(1) => bussci_tx,
      BUS_TX(2) => bustc_tx,
      BUS_TX(3) => bustdc_tx,

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
      FLASH_CS          => flash_ncs_i,
      FLASH_CLK         => FLASH_SCLK,
      FLASH_IN          => FLASH_MISO,
      FLASH_OUT         => FLASH_MOSI,
      PROGRAMN          => PROGRAMN,
      REBOOT_IN         => common_ctrl_reg(15),
      --SPI
      SPI_CS_OUT        => spi_cs,
      SPI_MOSI_OUT      => spi_mosi,
      SPI_MISO_IN       => spi_miso,
      SPI_CLK_OUT       => spi_clk,
      --Header
      HEADER_IO         => HDR_IO(9 downto 0),
      ADDITIONAL_REG(0) => led_off,
      --LCD
      LCD_DATA_IN       => (others => '0'),
      --ADC
      ADC_CS            => ADC_NCS,
      ADC_MOSI          => ADC_MOSI,
      ADC_MISO          => ADC_MISO,
      ADC_CLK           => ADC_SCLK,
      --Trigger & Monitor 
      MONITOR_INPUTS    => monitor_inputs_i,
      TRIG_GEN_INPUTS   => trigger_inputs_i,
      TRIG_GEN_OUTPUTS(1 downto 0)  => BACK_GPIO(3 downto 2),
      TRIG_GEN_OUTPUTS(3 downto 2)  => SPARE(1 downto 0),
      --SED
      SED_ERROR_OUT     => sed_error_i,
      --Slowcontrol
      BUS_RX            => bustools_rx,
      BUS_TX            => bustools_tx,
      --Control master for default settings
      BUS_MASTER_IN     => bus_master_in,
      BUS_MASTER_OUT    => bus_master_out,
      BUS_MASTER_ACTIVE => bus_master_active,
      DEBUG_OUT         => debug_tools
      );



  FLASH_HOLD <= '1';
  FLASH_WP   <= '1';

---------------------------------------------------------------------------
-- I/O
---------------------------------------------------------------------------

  CS <= spi_cs(3 downto 0);
  spi_miso(3 downto 0) <= MISO;
  
  MOSI <= spi_mosi(0) when spi_cs(0) = '0' 
     else spi_mosi(1) when spi_cs(1) = '0' 
     else spi_mosi(2) when spi_cs(2) = '0' 
     else spi_mosi(3) when spi_cs(3) = '0' 
     else '0';
  
  SCK  <= spi_clk(0) when spi_cs(0) = '0' 
     else spi_clk(1) when spi_cs(1) = '0' 
     else spi_clk(2) when spi_cs(2) = '0' 
     else spi_clk(3) when spi_cs(3) = '0' 
     else '1';


  monitor_inputs_i <= INP(MONITOR_INPUT_NUM-1 downto 0);
  trigger_inputs_i <= INP(TRIG_GEN_INPUT_NUM-1 downto 0);
  hit_in_i         <= INP(NUM_TDC_CHANNELS-2 downto 0);

  HDR_IO(15 downto 10) <= (others => '0');
--   TEST(13 downto 1)    <= (others => '0');
  TEST(14) <= flash_ncs_i;
  FLASH_NCS <= flash_ncs_i;
  
---------------------------------------------------------------------------
-- LED
---------------------------------------------------------------------------

  LED_SFP_GREEN  <= not med2int(0).stat_op(9) or led_off;
  LED_SFP_RED    <= not (med2int(0).stat_op(10) or med2int(0).stat_op(11)) or led_off;
  LED_SFP_YELLOW <= not med2int(0).stat_op(8) or led_off;
  LED            <= x"F0";
  LED_RJ_GREEN   <= "00";
  LED_RJ_RED     <= "11";
  LED_EXT_CLOCK  <= IN_SELECT_EXT_CLOCK or led_off;
  
-------------------------------------------------------------------------------
-- TDC
-------------------------------------------------------------------------------
THE_TDC : entity work.TDC_FF
  generic map(
    CHANNELS => 17
    )
  port map(
    CLK        => CLK_125,
    SYSCLK     => clk_sys,
    RESET_IN   => reset_i,
    SIGNAL_IN  => INP(16 downto 0),
    
    BUS_RX => bustdc_rx,
    BUS_TX => bustdc_tx,

    READOUT_RX => readout_rx,
    READOUT_TX => readout_tx  
    
    );




-------------------------------------------------------------------------------
-- No trigger/data endpoint included
-------------------------------------------------------------------------------
readout_tx(0).data_finished <= '1';
readout_tx(0).data_write    <= '0';
readout_tx(0).busy_release  <= '1';    
  
end architecture;



