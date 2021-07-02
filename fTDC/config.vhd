library ieee;
USE IEEE.std_logic_1164.ALL;
use ieee.numeric_std.all;
use work.trb_net_std.all;

package config is


------------------------------------------------------------------------------
--Begin of design configuration
------------------------------------------------------------------------------


--set to 0 for backplane serdes, set to 1 for SFP serdes
    constant SERDES_NUM             : integer := 1;

--TDC settings
  constant FPGA_TYPE               : integer  := 5;  --3: ECP3, 5: ECP5
  constant FPGA_SIZE               : string := "45KUM";
  constant NUM_TDC_CHANNELS        : integer range 1 to 65 := 11;  -- number of tdc channels per module
  constant NUM_TDC_CHANNELS_POWER2 : integer range 0 to 6  := 4;  --the nearest power of two, for convenience reasons 
  constant DOUBLE_EDGE_TYPE        : integer range 0 to 3  := 3;  --double edge type:  0, 1, 2,  3
  constant RING_BUFFER_SIZE        : integer range 0 to 7  := 7;  --ring buffer size
  constant TDC_DATA_FORMAT         : integer range 0 to 3  := 0;  --type of data format for the TDC

  constant EVENT_BUFFER_SIZE        : integer range 9 to 13 := 10; -- size of the event buffer, 2**N
  constant EVENT_MAX_SIZE           : integer := 400;             --maximum event size. Must not exceed EVENT_BUFFER_SIZE/2

    
--Use sync mode, RX clock for all parts of the FPGA
    constant USE_RXCLOCK            : integer := c_NO;
    constant USE_120_MHZ            : integer := c_NO;
    
--Address settings   
    constant INIT_ADDRESS           : std_logic_vector := x"F6DC";
    constant BROADCAST_SPECIAL_ADDR : std_logic_vector := x"91";
   
    constant INCLUDE_UART           : integer  := c_NO;  --300 slices
    constant INCLUDE_SPI            : integer  := c_YES; --300 slices
    constant INCLUDE_LCD            : integer  := c_NO;  --800 slices
    constant INCLUDE_DEBUG_INTERFACE: integer  := c_NO; --300 slices

    --input monitor and trigger generation logic
    constant INCLUDE_TRIGGER_LOGIC  : integer  := c_NO; --400 slices @32->2
    constant INCLUDE_STATISTICS     : integer  := c_YES; --1300 slices, 1 RAM @32
    constant TRIG_GEN_INPUT_NUM     : integer  := 32;
    constant TRIG_GEN_OUTPUT_NUM    : integer  := 4;
    constant MONITOR_INPUT_NUM      : integer  := 64;        
    
------------------------------------------------------------------------------
--End of design configuration
------------------------------------------------------------------------------


  type data_t is array (0 to 1023) of std_logic_vector(7 downto 0);
  constant LCD_DATA : data_t := (others => x"00");

------------------------------------------------------------------------------
--Select settings by configuration 
------------------------------------------------------------------------------
    type intlist_t is array(0 to 7) of integer;
    type hw_info_t is array(0 to 7) of unsigned(31 downto 0);
    constant HW_INFO_BASE            : unsigned(31 downto 0) := x"A7000000";
    
            
  --declare constants, filled in body                          
    constant HARDWARE_INFO        : std_logic_vector(31 downto 0);
    constant CLOCK_FREQUENCY      : integer;
    constant MEDIA_FREQUENCY      : integer;
    constant INCLUDED_FEATURES      : std_logic_vector(63 downto 0);
    
    
end;

package body config is
--compute correct configuration mode
  
  constant HARDWARE_INFO        : std_logic_vector(31 downto 0) := std_logic_vector( HW_INFO_BASE );
  constant CLOCK_FREQUENCY      : integer := 100;
  constant MEDIA_FREQUENCY      : integer := 200;
  
function generateIncludedFeatures return std_logic_vector is
  variable t : std_logic_vector(63 downto 0);
  begin
    t               := (others => '0');
    t(63 downto 56) := std_logic_vector(to_unsigned(2,8)); --table version 1

    t(7 downto 0)   := std_logic_vector(to_unsigned(1,8));
--     t(11 downto 8)  := std_logic_vector(to_unsigned(DOUBLE_EDGE_TYPE,4));
--     t(14 downto 12) := std_logic_vector(to_unsigned(RING_BUFFER_SIZE,3));
    t(15)           := '1'; --TDC
    t(17 downto 16) := "00";
    
    t(40 downto 40) := std_logic_vector(to_unsigned(INCLUDE_LCD,1));
    t(42 downto 42) := std_logic_vector(to_unsigned(INCLUDE_SPI,1));
    t(43 downto 43) := std_logic_vector(to_unsigned(INCLUDE_UART,1));
    t(44 downto 44) := std_logic_vector(to_unsigned(INCLUDE_STATISTICS,1));
    t(51 downto 48) := std_logic_vector(to_unsigned(INCLUDE_TRIGGER_LOGIC,4));
    t(52 downto 52) := std_logic_vector(to_unsigned(USE_120_MHZ,1));
    t(53 downto 53) := std_logic_vector(to_unsigned(USE_RXCLOCK,1));
    t(54 downto 54) := "0";--std_logic_vector(to_unsigned(USE_EXTERNAL_CLOCK,1));
    return t;
  end function;  

  constant INCLUDED_FEATURES : std_logic_vector(63 downto 0) := generateIncludedFeatures;    

end package body;
