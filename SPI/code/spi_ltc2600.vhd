library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

library work;
use work.trb_net_std.all;

entity spi_ltc2600 is
  generic(
    BITS       : integer range 8 to 32   := 32;
    WAITCYCLES : integer range 2 to 1024 := 7
    );
  port(
    CLK_IN       : in  std_logic;
    RESET_IN     : in  std_logic;
    -- Slave bus
    BUS_READ_IN  : in  std_logic;
    BUS_WRITE_IN : in  std_logic;
    BUS_BUSY_OUT : out std_logic;
    BUS_ACK_OUT  : out std_logic;
    BUS_ADDR_IN  : in  std_logic_vector(4 downto 0);
    BUS_DATA_IN  : in  std_logic_vector(31 downto 0);
    BUS_DATA_OUT : out std_logic_vector(31 downto 0);
    -- SPI connections
    SPI_CS_OUT   : out std_logic_vector(15 downto 0);
    SPI_SDI_IN   : in  std_logic_vector(15 downto 0);
    SPI_SDO_OUT  : out std_logic_vector(15 downto 0);
    SPI_SCK_OUT  : out std_logic_vector(15 downto 0);
    SPI_CLR_OUT  : out std_logic_vector(15 downto 0)
    );
end entity;


architecture spi_ltc2600_arch of spi_ltc2600 is

  type   ram_t is array(0 to 15) of std_logic_vector(31 downto 0);
  signal ram : ram_t;

  signal ram_addr       : integer range 0 to 31;
  signal ram_data       : std_logic_vector(31 downto 0);
  signal ctrl_reg       : std_logic_vector(31 downto 0);
  signal start          : std_logic;
  signal chipselect_reg : std_logic_vector(15 downto 0) := x"0001";
  signal clear_reg      : std_logic_vector(15 downto 0) := x"0000";
--   signal invert_reg     : std_logic;
  signal override_cs, override_sck, override_sdo : std_logic_vector(15 downto 0) := x"0000";
  signal invert_cs, invert_sck, invert_sdo       : std_logic_vector(15 downto 0) := x"0000";
  
  signal spi_cs  : std_logic_vector(15 downto 0);
  signal spi_sck : std_logic;
  signal spi_sdo  : std_logic;
  signal spi_sdi : std_logic;

  signal word_count : integer range 0 to 31 := 1;
  signal bit_count  : integer range 0 to BITS-1;
  signal time_count : integer range 0 to 1023;
  signal readback   : std_logic_vector(31 downto 0);
  signal blocked    : std_logic :='0';
  signal sudolock   : std_logic;
  signal reset_fsm  : std_logic;
  type   fsm_t is (IDLE, WAIT_STATE, SET, TOGGLE_CS, TOGGLE_CS_0, TOGGLE_CS_1, TOGGLE_CS_2, FINISH);
  signal fsm_state : fsm_t;
  signal word_length : integer range 0 to BITS := BITS;
  
  signal wait_cycles : integer range 0 to 1023 := WAITCYCLES;
  
begin

  PROC_MEM : process
    variable addr : integer range 0 to 15;
  begin
    wait until rising_edge(CLK_IN);
    addr := to_integer(unsigned(BUS_ADDR_IN(3 downto 0)));

    BUS_ACK_OUT  <= '0';
    BUS_BUSY_OUT <= '0';
    start        <= '0';
    reset_fsm    <= '0';

    if BUS_WRITE_IN = '1' then
      if fsm_state = IDLE and blocked = '0' then
        BUS_ACK_OUT <= '1';
        if BUS_ADDR_IN(4) = '0' then     --0x00..0x0F
          ram(addr) <= BUS_DATA_IN;
        elsif BUS_ADDR_IN(3 downto 0) = x"4" then  --0x14
          clear_reg <= BUS_DATA_IN(15 downto 0);
        elsif BUS_ADDR_IN(3 downto 0) = x"5" then
          override_sdo <= BUS_DATA_IN(15 downto 0);
          invert_sdo   <= BUS_DATA_IN(31 downto 16);
        elsif BUS_ADDR_IN(3 downto 0) = x"6" then
          override_sck <= BUS_DATA_IN(15 downto 0);
          invert_sck   <= BUS_DATA_IN(31 downto 16);
        elsif BUS_ADDR_IN(3 downto 0) = x"7" then
          override_cs  <= BUS_DATA_IN(15 downto 0);
          invert_cs    <= BUS_DATA_IN(31 downto 16);
--         elsif BUS_ADDR_IN(3 downto 0) = x"8" then  --0x18
--           invert_reg <= BUS_DATA_IN(0);
        elsif BUS_ADDR_IN(3 downto 0) = x"9" then  -- 0x19
          word_length <= to_integer(unsigned(BUS_DATA_IN(5 downto 0)));
        elsif BUS_ADDR_IN(3 downto 0) = x"a" then  -- 0x1a
          wait_cycles <= to_integer(unsigned(BUS_DATA_IN(9 downto 0)));
        elsif BUS_ADDR_IN(3 downto 0) = x"1" then  --0x11
          ctrl_reg <= BUS_DATA_IN;
          blocked  <= BUS_DATA_IN(16)  and or_all(BUS_DATA_IN(4 downto 0));
          start    <= (not sudolock or BUS_DATA_IN(17)) and or_all(BUS_DATA_IN(4 downto 0));
        elsif BUS_ADDR_IN(3 downto 0) = x"0" then  --0x10
          chipselect_reg <= BUS_DATA_IN(15 downto 0);
        end if;
      elsif BUS_ADDR_IN = "10011" then   --Reg. 0x13
        sudolock    <= BUS_DATA_IN(17);
        reset_fsm   <= BUS_DATA_IN(31);
        BUS_ACK_OUT <= '1';
      else
        BUS_BUSY_OUT <= '1';
      end if;
    end if;

    if BUS_READ_IN = '1' then
      if BUS_ADDR_IN(4) = '0' then
        BUS_DATA_OUT <= ram(addr);
      elsif BUS_ADDR_IN(3 downto 0) = x"0" then
        BUS_DATA_OUT(15 downto 0)  <= chipselect_reg;
        BUS_DATA_OUT(31 downto 16) <= x"0000";
      elsif BUS_ADDR_IN(3 downto 0) = x"1" then
        BUS_DATA_OUT <= ctrl_reg;
      elsif BUS_ADDR_IN(3 downto 0) = x"2" then
        BUS_DATA_OUT <= readback;
        blocked      <= '0';
      elsif BUS_ADDR_IN(3 downto 0) = x"3" then
        BUS_DATA_OUT     <= (others => '0');
        BUS_DATA_OUT(17) <= sudolock;
      elsif BUS_ADDR_IN(3 downto 0) = x"4" then
        BUS_DATA_OUT(15 downto 0)  <= clear_reg;
        BUS_DATA_OUT(31 downto 16) <= x"0000";
      elsif BUS_ADDR_IN(3 downto 0) = x"5" then
        BUS_DATA_OUT(31 downto 16) <= invert_sdo;
        BUS_DATA_OUT(15 downto 0)  <= override_sdo;
      elsif BUS_ADDR_IN(3 downto 0) = x"6" then
        BUS_DATA_OUT(31 downto 16) <= invert_sck;
        BUS_DATA_OUT(15 downto 0)  <= override_sck;
      elsif BUS_ADDR_IN(3 downto 0) = x"7" then
        BUS_DATA_OUT(31 downto 16) <= invert_cs;
        BUS_DATA_OUT(15 downto 0)  <= override_cs;
--       elsif BUS_ADDR_IN(3 downto 0) = x"8" then
--         BUS_DATA_OUT(0)           <= invert_reg;
--         BUS_DATA_OUT(31 downto 1) <= (others => '0');
      elsif BUS_ADDR_IN(3 downto 0) = x"9" then
        BUS_DATA_OUT             <= (others => '0');
        BUS_DATA_OUT(5 downto 0) <= std_logic_vector(to_unsigned(word_length,6));
      elsif BUS_ADDR_IN(3 downto 0) = x"a" then
        BUS_DATA_OUT             <= (others => '0');
        BUS_DATA_OUT(9 downto 0) <= std_logic_vector(to_unsigned(wait_cycles,10));
      end if;
      BUS_ACK_OUT <= '1';
    end if;

    ram_data <= ram(ram_addr);
    
  end process;




  PROC_FSM : process
  begin
    wait until rising_edge(CLK_IN);
    case fsm_state is
      when IDLE =>

        if start = '1' then
          ram_addr   <= 0;
          word_count <= to_integer(unsigned(ctrl_reg(4 downto 0)));
          bit_count  <= word_length-1;
          time_count <= wait_cycles;
          fsm_state  <= WAIT_STATE;
          spi_cs     <= chipselect_reg;
          spi_sck    <= '1';
        else
          spi_cs  <= x"0000";
          spi_sck <= '1';
        end if;
        
      when WAIT_STATE =>
        if time_count = 0 then
          fsm_state <= SET;
        else
          time_count <= time_count - 1;
        end if;
        
      when SET =>
        time_count <= wait_cycles;
        spi_sck    <= not spi_sck;
        if spi_sck = '1' then
          spi_sdo <= ram_data(bit_count);
          if bit_count /= 0 then
            bit_count <= bit_count - 1;
            fsm_state <= WAIT_STATE;
          else
            ram_addr  <= ram_addr + 1;
            bit_count <= word_length-1;
            if ram_addr /= word_count -1 then
              if ctrl_reg(7) = '0' then  --one CS phase
                fsm_state <= WAIT_STATE;
              else                       --one CS per word
                fsm_state <= TOGGLE_CS;
              end if;
            else
              fsm_state <= FINISH;
            end if;
          end if;
        else
          fsm_state <= WAIT_STATE;
          readback  <= readback(30 downto 0) & spi_sdi;
        end if;
      when TOGGLE_CS =>
        if time_count = 0 and spi_sck = '0' then
          time_count <= 7;
          spi_sck    <= not spi_sck;
          readback   <= readback(30 downto 0) & spi_sdi;
        elsif time_count = 0 and spi_sck = '1' then
          fsm_state <= TOGGLE_CS_0;
        else
          time_count <= time_count - 1;
        end if;
      when TOGGLE_CS_0 =>
        time_count <= time_count - 1;
        if time_count = 0 then
          spi_cs     <= x"0000";
          fsm_state  <= TOGGLE_CS_1;
          time_count <= 7;
        end if;
      when TOGGLE_CS_1 =>
        time_count <= time_count - 1;
        if time_count = 0 then
          spi_cs     <= chipselect_reg;
          bit_count  <= word_length-1;
          fsm_state  <= WAIT_STATE;
          time_count <= wait_cycles;
        end if;
      when TOGGLE_CS_2 =>
        time_count <= time_count - 1;
        if time_count = 0 then
          spi_sck    <= not spi_sck;
          fsm_state  <= WAIT_STATE;
          time_count <= wait_cycles;
        end if;
      when FINISH =>
        if time_count = 0 and spi_sck = '0' then
          time_count <= wait_cycles;
          spi_sck    <= not spi_sck;
          readback   <= readback(30 downto 0) & spi_sdi;
        elsif time_count = 0 and spi_sck = '1' then
          fsm_state <= IDLE;
        else
          time_count <= time_count - 1;
        end if;
    end case;
    if RESET_IN = '1' or reset_fsm = '1' then
      fsm_state <= IDLE;
    end if;
  end process;

-- Outputs and Inputs

spi_sdi <= or_all(SPI_SDI_IN and spi_cs);

gen_outputs : for i in 0 to 15 generate
  SPI_CS_OUT(i)  <= not ((spi_cs(i) and not override_cs(i))  xor invert_cs(i));
  SPI_SDO_OUT(i) <=      (spi_sdo   and spi_cs(i) and not override_sdo(i)) xor invert_sdo(i);
  SPI_SCK_OUT(i) <=      (spi_sck   and not override_sck(i)) xor invert_sck(i);
end generate;

SPI_CLR_OUT <= clear_reg;
  

  
end architecture;
