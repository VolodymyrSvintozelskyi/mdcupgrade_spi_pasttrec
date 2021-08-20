-- std package
library ieee;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_ARITH.ALL;           --> should be replaced with the ieee
USE IEEE.std_logic_UNSIGNED.ALL;        --> standard package ieee.numeric_std

package trb_net_std is

  type channel_config_t is array(0 to 3) of integer;
  type array_32_t is array(integer range <>) of std_logic_vector(31 downto 0);
  type multiplexer_config_t is array(0 to 2**3-1) of integer;

--Trigger types
  constant TRIG_PHYS         : std_logic_vector(3 downto 0) := x"1";
  constant TRIG_MDC_CAL      : std_logic_vector(3 downto 0) := x"9";
  constant TRIG_SHW_CAL      : std_logic_vector(3 downto 0) := x"A";
  constant TRIG_SHW_PED      : std_logic_vector(3 downto 0) := x"B";
--Trigger Info
  constant TRIG_SUPPRESS_BIT : integer range 0 to 15 := 0;



-- some basic definitions for the whole network
-----------------------------------------------

  constant c_DATA_WIDTH        : integer   := 16;
  constant c_NUM_WIDTH         : integer   := 3;
  constant c_MUX_WIDTH         : integer   := 3; --!!!


--assigning channel names
  constant c_TRG_LVL1_CHANNEL  : integer := 0;
  constant c_DATA_CHANNEL      : integer := 1;
  constant c_IPU_CHANNEL       : integer := 1;
  constant c_UNUSED_CHANNEL    : integer := 2;
  constant c_SLOW_CTRL_CHANNEL : integer := 3;

--api_type generic
  constant c_API_ACTIVE   : integer := 1;
  constant c_API_PASSIVE  : integer := 0;

--sbuf_version generic
  constant c_SBUF_FULL     : integer := 0;
  constant c_SBUF_FAST     : integer := 0;
  constant c_SBUF_HALF     : integer := 1;
  constant c_SBUF_SLOW     : integer := 1;
  constant c_SECURE_MODE   : integer := 1;
  constant c_NON_SECURE_MODE : integer := 0;

--fifo_depth
  constant c_FIFO_NONE     : integer := 0;
  constant c_FIFO_2PCK     : integer := 1;
  constant c_FIFO_SMALL    : integer := 1;
  constant c_FIFO_4PCK     : integer := 2;
  constant c_FIFO_MEDIUM   : integer := 2;
  constant c_FIFO_8PCK     : integer := 3;
  constant c_FIFO_BIG      : integer := 3;
  constant c_FIFO_BRAM     : integer := 6;
  constant c_FIFO_BIGGEST  : integer := 6;
  constant c_FIFO_INFTY    : integer := 7;

--simple logic
  constant c_YES  : integer := 1;
  constant c_NO   : integer := 0;
  constant c_MONITOR : integer := 2;
  constant c_I2C  : integer := 3;
  constant c_XDNA : integer := 4;

--standard values
  constant std_SBUF_VERSION     : integer := c_SBUF_FULL;
  constant std_IBUF_SECURE_MODE : integer := c_SECURE_MODE;
  constant std_USE_ACKNOWLEDGE  : integer := c_YES;
  constant std_USE_REPLY_CHANNEL: integer := c_YES;
  constant std_FIFO_DEPTH       : integer := c_FIFO_BRAM;
  constant std_DATA_COUNT_WIDTH : integer := 7; --max 7
  constant std_TERM_SECURE_MODE : integer := c_YES;
  constant std_MUX_SECURE_MODE  : integer := c_NO;
  constant std_FORCE_REPLY      : integer := c_YES;
  constant cfg_USE_CHECKSUM      : channel_config_t   := (c_NO,c_YES,c_NO,c_YES);
  constant cfg_USE_ACKNOWLEDGE   : channel_config_t   := (c_YES,c_YES,c_NO,c_YES);
  constant cfg_FORCE_REPLY       : channel_config_t   := (c_YES,c_YES,c_YES,c_YES);
  constant cfg_USE_REPLY_CHANNEL : channel_config_t   := (c_YES,c_YES,c_YES,c_YES);
  constant c_MAX_IDLE_TIME_PER_PACKET : integer := 24;
  constant std_multipexer_config : multiplexer_config_t := (others => c_NO);

--packet types
  constant TYPE_DAT : std_logic_vector(2 downto 0) := "000";
  constant TYPE_HDR : std_logic_vector(2 downto 0) := "001";
  constant TYPE_EOB : std_logic_vector(2 downto 0) := "010";
  constant TYPE_TRM : std_logic_vector(2 downto 0) := "011";
  constant TYPE_ACK : std_logic_vector(2 downto 0) := "101";
  constant TYPE_ILLEGAL : std_logic_vector(2 downto 0) := "111";

--Media interface error codes
  constant ERROR_OK     : std_logic_vector(2 downto 0) := "000"; --transmission ok
  constant ERROR_ENCOD  : std_logic_vector(2 downto 0) := "001"; --transmission error by encoding
  constant ERROR_RECOV  : std_logic_vector(2 downto 0) := "010"; --transmission error, reconstructed
  constant ERROR_FATAL  : std_logic_vector(2 downto 0) := "011"; --transmission error, fatal
  constant ERROR_WAIT   : std_logic_vector(2 downto 0) := "110"; --link awaiting initial response
  constant ERROR_NC     : std_logic_vector(2 downto 0) := "111"; --media not connected


--special addresses
  constant ILLEGAL_ADDRESS   : std_logic_vector(15 downto 0) := x"0000";
  constant BROADCAST_ADDRESS : std_logic_vector(15 downto 0) := x"ffff";

--command definitions
  constant LINK_STARTUP_WORD : std_logic_vector(15 downto 0) := x"e110";
  constant SET_ADDRESS : std_logic_vector(15 downto 0) := x"5EAD";
  constant ACK_ADDRESS : std_logic_vector(15 downto 0) := x"ACAD";
  constant READ_ID     : std_logic_vector(15 downto 0) := x"5E1D";

--common registers
  --maximum: 4, because of regio implementation
  constant std_COMSTATREG  : integer := 10;
  constant std_COMCTRLREG  : integer := 3;
    --needed address width for common registers
  constant std_COMneededwidth : integer := 4;
  constant c_REGIO_ADDRESS_WIDTH : integer := 16;
  constant c_REGIO_REGISTER_WIDTH : integer := 32;
  constant c_REGIO_REG_WIDTH : integer := 32;
  constant c_regio_timeout_bit : integer := 5;

--RegIO operation dtype
  constant c_network_control_type : std_logic_vector(3 downto 0) := x"F";
  constant c_read_register_type   : std_logic_vector(3 downto 0) := x"8";
  constant c_write_register_type  : std_logic_vector(3 downto 0) := x"9";
  constant c_read_multiple_type   : std_logic_vector(3 downto 0) := x"A";
  constant c_write_multiple_type  : std_logic_vector(3 downto 0) := x"B";

  constant c_BUS_HANDLER_MAX_PORTS : integer := 64;
  type c_BUS_HANDLER_ADDR_t is array(0 to c_BUS_HANDLER_MAX_PORTS) of std_logic_vector(15 downto 0);
  type c_BUS_HANDLER_WIDTH_t is array(0 to c_BUS_HANDLER_MAX_PORTS) of integer range 0 to 16;


--Names of 16bit words
  constant c_H0 : std_logic_vector(2 downto 0) := "100";
  constant c_F0 : std_logic_vector(2 downto 0) := "000";
  constant c_F1 : std_logic_vector(2 downto 0) := "001";
  constant c_F2 : std_logic_vector(2 downto 0) := "010";
  constant c_F3 : std_logic_vector(2 downto 0) := "011";

  constant c_H0_next : std_logic_vector(2 downto 0) := "011";
  constant c_F0_next : std_logic_vector(2 downto 0) := "100";
  constant c_F1_next : std_logic_vector(2 downto 0) := "000";
  constant c_F2_next : std_logic_vector(2 downto 0) := "001";
  constant c_F3_next : std_logic_vector(2 downto 0) := "010";

  constant c_max_word_number : std_logic_vector(2 downto 0) := "100";
  --constant VERSION_NUMBER_TIME  : std_logic_vector(31 downto 0)   := conv_std_logic_vector(1234567890,32);


  type CTRLBUS_TX is record
    data       : std_logic_vector(31 downto 0);
    ack        : std_logic;
    wack,rack  : std_logic; --for the old-fashioned guys
    unknown    : std_logic;
    nack       : std_logic;
  end record;

  type CTRLBUS_RX is record
    data       : std_logic_vector(31 downto 0);
    addr       : std_logic_vector(15 downto 0);
    write      : std_logic;
    read       : std_logic;
    timeout    : std_logic;
  end record; 

  
  type READOUT_RX is record 
    data_valid         : std_logic;
    valid_timing_trg   : std_logic;
    valid_notiming_trg : std_logic;
    invalid_trg        : std_logic;
    --
    trg_type           : std_logic_vector( 3 downto 0);
    trg_number         : std_logic_vector(15 downto 0);
    trg_code           : std_logic_vector( 7 downto 0);
    trg_information    : std_logic_vector(23 downto 0);
    trg_int_number     : std_logic_vector(15 downto 0);    
    --
    trg_multiple       : std_logic;
    trg_timeout        : std_logic;
    trg_spurious       : std_logic;
    trg_missing        : std_logic;
    trg_spike          : std_logic;
    --
    buffer_almost_full : std_logic;
  end record; 
  
  
  type READOUT_TX is record
    busy_release  : std_logic;
    statusbits    : std_logic_vector(31 downto 0);
    data          : std_logic_vector(31 downto 0);
    data_write    : std_logic;
    data_finished : std_logic;
  end record;
    
  
  type TIMERS is record
    microsecond         : std_logic_vector (31 downto 0); --global time, microseconds
    clock               : std_logic_vector ( 7 downto 0); --local time running with chip frequency
    last_trigger        : std_logic_vector (31 downto 0); --local time, resetted with each trigger
    tick_ms             : std_logic;
    tick_us             : std_logic;
    network_address     : std_logic_vector (15 downto 0);
    temperature         : std_logic_vector (11 downto 0);
    uid                 : std_logic_vector (63 downto 0);
  end record;
    
  type MED2INT is record
    data      : std_logic_vector(15 downto 0);
    packet_num: std_logic_vector(2 downto 0);
    dataready : std_logic;
    tx_read   : std_logic;
    stat_op   : std_logic_vector(15 downto 0);
    clk_half  : std_logic;
    clk_full  : std_logic;
  end record;

  type INT2MED is record
    data      : std_logic_vector(15 downto 0);
    packet_num: std_logic_vector(2 downto 0);
    dataready : std_logic;
    ctrl_op   : std_logic_vector(15 downto 0);
  end record;
  
  type API_RX_REC is record
    data           : std_logic_vector(15 downto 0);
    packet_num     : std_logic_vector(2 downto 0);
    dataready      : std_logic;
    dtype          : std_logic_vector(3 downto 0);
    running        : std_logic;
    seq_num        : std_logic_vector(7 downto 0);
    read_tx        : std_logic;
  end record;  

  type API_TX_REC is record
    data           : std_logic_vector(15 downto 0);
    packet_num     : std_logic_vector(2 downto 0);
    dataready      : std_logic;
    short_transfer : std_logic;
    dtype          : std_logic_vector(3 downto 0);
    error_pattern  : std_logic_vector(31 downto 0);
    send           : std_logic;
    read_rx        : std_logic;
  end record;  
  
  type NETBUS is record
    dataready      : std_logic;
    data           : std_logic_vector(15 downto 0);
    packet_num     : std_logic_vector(2 downto 0);
  end record;
  
  
  type std_logic_vector_array_36 is array (integer range <>) of std_logic_vector(35 downto 0);
  type std_logic_vector_array_32 is array (integer range <>) of std_logic_vector(31 downto 0);
  type std_logic_vector_array_31 is array (integer range <>) of std_logic_vector(30 downto 0);
  type std_logic_vector_array_24 is array (integer range <>) of std_logic_vector(23 downto 0);
  type std_logic_vector_array_11 is array (integer range <>) of std_logic_vector(10 downto 0);
  type std_logic_vector_array_8  is array (integer range <>) of std_logic_vector(7 downto 0);
  type int_array_t is array(integer range <>) of integer;

  type ctrlbus_tx_array_t  is array (integer range <>) of CTRLBUS_TX;
  type ctrlbus_rx_array_t  is array (integer range <>) of CTRLBUS_RX;
  type readout_tx_array_t  is array (integer range <>) of READOUT_TX;
  type med2int_array_t     is array (integer range <>) of MED2INT;
  type int2med_array_t     is array (integer range <>) of INT2MED;
    
--function declarations
  function and_all (arg : std_logic_vector)
    return std_logic;
  function or_all  (arg : std_logic_vector)
    return std_logic;
  function all_zero (arg : std_logic_vector)
    return std_logic;
  function xor_all  (arg : std_logic_vector)
    return std_logic;

  function get_bit_position  (arg : std_logic_vector)
    return integer;

  function is_time_reached  (timer : integer; time : integer; period : integer)
    return std_logic;

  function Log2( input:integer ) return integer;
  function count_ones( input:std_logic_vector ) return integer;
  function minimum (LEFT, RIGHT: INTEGER) return INTEGER;
  function maximum (LEFT, RIGHT: INTEGER) return INTEGER;


end package trb_net_std;

package body trb_net_std is
 

  function and_all (arg : std_logic_vector)
    return std_logic is
    variable tmp : std_logic := '1';
    begin
      tmp := '1';
      for i in arg'range loop
        tmp := tmp and arg(i);
      end loop;  -- i
      return tmp;
  end function and_all;

  function or_all (arg : std_logic_vector)
    return std_logic is
    variable tmp : std_logic := '1';
    begin
      tmp := '0';
      for i in arg'range loop
        tmp := tmp or arg(i);
      end loop;  -- i
      return tmp;
  end function or_all;

  function all_zero (arg : std_logic_vector)
    return std_logic is
	 variable tmp : std_logic := '1';
	 begin
      for i in arg'range loop
		  tmp := not arg(i);
        exit when tmp = '0';
      end loop;  -- i
      return tmp;
  end function all_zero;

  function xor_all (arg : std_logic_vector)
    return std_logic is
    variable tmp : std_logic := '0';
    begin
      tmp := '0';
      for i in arg'range loop
        tmp := tmp xor arg(i);
      end loop;  -- i
      return tmp;
  end function xor_all;

  function get_bit_position (arg : std_logic_vector)
    return integer is
    variable tmp : integer := 0;
    begin
      tmp := 0;
      for i in  arg'range loop
        if arg(i) = '1' then
          return i;
        end if;
        --exit when arg(i) = '1';
      end loop;  -- i
      return 0;
  end get_bit_position;

  function is_time_reached  (timer : integer; time : integer; period : integer)
    return std_logic is
    variable i : integer range 0 to 1 := 0;
    variable t : std_logic_vector(27 downto 0) := conv_std_logic_vector(timer,28);
    begin
      i := 0;
      if period = 10 then
        case time is
          when 1300000000 => if t(27) = '1' then i := 1; end if;
          when 640000 => if t(16) = '1' then i := 1; end if;
          when 80000  => if t(13) = '1' then i := 1; end if;
          when 10000  => if t(10) = '1' then i := 1; end if;
          when 1200   => if t(7)  = '1' then i := 1; end if;
          when others => if timer >= time/period then i := 1; end if;
        end case;
      elsif period = 40 then
        case time is
          when 1300000000 => if t(25) = '1' then i := 1; end if;
          when 640000 => if t(14) = '1' then i := 1; end if;
          when 80000  => if t(11) = '1' then i := 1; end if;
          when 10000  => if t(8) = '1' then i := 1; end if;
          when 1200   => if t(5)  = '1' then i := 1; end if;
          when others => if timer >= time/period then i := 1; end if;
        end case;
      else
        if timer = time/period then i := 1; end if;
      end if;
      if i = 1 then  return '1'; else return '0'; end if;
    end is_time_reached;


  function Log2( input:integer ) return integer is
    variable temp,log:integer;
    begin
      temp:=input;
      log:=0;
      while (temp /= 0) loop
      temp:=temp/2;
      log:=log+1;
      end loop;
      return log;
      end function log2;

  function count_ones( input:std_logic_vector ) return integer is
    variable temp:std_logic_vector(input'range);
    begin
      temp := (others => '0');
      for i in input'range loop
--        if input(i) = '1' then
          temp := temp + input(i);
--        end if;
      end loop;
      return conv_integer(temp);
      end function count_ones;

      
function minimum (LEFT, RIGHT: INTEGER) return INTEGER is
  begin
    if LEFT < RIGHT then return LEFT;
    else return RIGHT;
    end if;
  end function;        

function maximum (LEFT, RIGHT: INTEGER) return INTEGER is
  begin
    if LEFT > RIGHT then return LEFT;
    else return RIGHT;
    end if;
  end function;       
  
end package body trb_net_std;

