library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

library work;
use work.trb_net_std.all;

entity spi_ltc2600_simpl is
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
    BUS_UNK_OUT  : out std_logic;
    BUS_ADDR_IN  : in  std_logic_vector(3 downto 0);
    BUS_DATA_IN  : in  std_logic_vector(31 downto 0);
    BUS_DATA_OUT : out std_logic_vector(31 downto 0);
    -- SPI connections
    SPI_CS_OUT   : out std_logic;
    SPI_SDI_IN   : in  std_logic;
    SPI_SDO_OUT  : out std_logic;
    SPI_SCK_OUT  : out std_logic;
    -- EXTERNAL RAM
    RAM_BUSY    : out std_logic;
    RAM_OFFSET  : out integer range 0 to 63;
    RAM_DATA    : in  std_logic_vector(31 downto 0)
    );
end entity;


architecture spi_ltc2600_arch of spi_ltc2600_simpl is


  signal ram_addr       : integer range 0 to 63;
  --signal ram_data       : std_logic_vector(31 downto 0);
  signal ctrl_reg       : std_logic_vector(31 downto 0) := (others => '0');
  signal start          : std_logic;
--   signal invert_reg     : std_logic;
  signal override_cs, override_sck, override_sdo : std_logic := '0';
  signal invert_cs, invert_sck, invert_sdo       : std_logic := '0';
  
  signal spi_cs  : std_logic;
  signal spi_sck : std_logic;
  signal spi_sdo : std_logic;
  signal spi_sdi : std_logic;

  signal word_count : integer range 0 to 63 := 1;
  signal bit_count  : integer range 0 to BITS-1;
  signal time_count : integer range 0 to 1023;
  signal readback   : std_logic_vector(31 downto 0);
  signal blocked    : std_logic :='0';
  signal reset_fsm  : std_logic;
  type   fsm_t is (IDLE, WAIT_STATE, SET, TOGGLE_CS, TOGGLE_CS_0, TOGGLE_CS_1, TOGGLE_CS_2, FINISH);
  signal fsm_state : fsm_t;
  signal word_length : integer range 0 to BITS := BITS;
  
  signal wait_cycles : integer range 0 to 1023 := WAITCYCLES;
  
begin

    --CTRL_REG               spi_ltc2600
    --mod
    --BITS	       option
    --31	       reset
    --30	       --
    --29..20	   wait_cycles
    --19..14	   word_length
    --13	       override_sdo
    --12	       override_sck
    --11	       override_cs
    --10	       invert_sdo
    --9	           invert_sck
    --8	           invert_cs
    --7	           block
    --6	           start
    --5..0	       word_count

    reset_fsm       <=  ctrl_reg(31);
    wait_cycles     <=  to_integer(unsigned(ctrl_reg(29 downto 20)));
    word_length     <=  to_integer(unsigned(ctrl_reg(19 downto 14)));
    override_sdo    <=  ctrl_reg(13);
    override_sck    <=  ctrl_reg(12);
    override_cs     <=  ctrl_reg(11);
    invert_sdo      <=  ctrl_reg(10);
    invert_sck      <=  ctrl_reg(9);
    invert_cs       <=  ctrl_reg(8);
    blocked         <=  ctrl_reg(7);
    start           <=  ctrl_reg(6);

    RAM_OFFSET      <= ram_addr;

    PROC_MEM : process
    begin
        wait until rising_edge(CLK_IN);

        BUS_ACK_OUT  <= '0';
        BUS_UNK_OUT  <= '0';
        BUS_BUSY_OUT <= '0';
        BUS_DATA_OUT <= (others => '0');
        ctrl_reg(6)  <= '0';
        ctrl_reg(31) <= '0';

        if BUS_WRITE_IN = '1' then
            if fsm_state = IDLE and blocked = '0' then
                BUS_ACK_OUT <= '1';
                if BUS_ADDR_IN(3 downto 0) = x"0" then                                   -- RESET
                    ctrl_reg(31) <= BUS_DATA_IN(31);
                elsif BUS_ADDR_IN(3 downto 0) = x"1" then                                   -- all CTRL_REG
                    ctrl_reg    <= BUS_DATA_IN(31 downto 0);
                    ctrl_reg(7) <= BUS_DATA_IN(7) and or_all(BUS_DATA_IN(5 downto 0));
                    ctrl_reg(6) <= BUS_DATA_IN(6) and or_all(BUS_DATA_IN(5 downto 0));
                elsif BUS_ADDR_IN(3 downto 0) = x"2" then                                   -- override / invert
                    ctrl_reg(13 downto 8)       <= BUS_DATA_IN(5 downto 0);
                elsif BUS_ADDR_IN(3 downto 0) = x"3" then                                   -- wait_cycles / word_length
                    ctrl_reg(29 downto 14)      <= BUS_DATA_IN(15 downto 0);
                elsif BUS_ADDR_IN(3 downto 0) = x"A" then  --0x11                           -- start transmitting
                    ctrl_reg(7 downto 0)        <= BUS_DATA_IN(7 downto 0);
                    ctrl_reg(7) <= BUS_DATA_IN(7) and or_all(BUS_DATA_IN(5 downto 0));
                    ctrl_reg(6) <= BUS_DATA_IN(6) and or_all(BUS_DATA_IN(5 downto 0));
                else
                    BUS_ACK_OUT <= '0';
                    BUS_UNK_OUT <= '1';
                end if;
            elsif BUS_ADDR_IN = "0000" then   --Reg. 0x13
                ctrl_reg(31)   <= BUS_DATA_IN(31);
                BUS_ACK_OUT <= '1';
            else
                BUS_BUSY_OUT <= '1';
            end if;
        end if;

        if BUS_READ_IN = '1' then
            BUS_ACK_OUT <= '1';
            if BUS_ADDR_IN(3 downto 0) = x"1" then                   -- all CTRL_REG
                BUS_DATA_OUT <= ctrl_reg;
            elsif BUS_ADDR_IN(3 downto 0) = x"2" then                   -- override / invert
                BUS_DATA_OUT(5 downto 0)  <= ctrl_reg(13 downto 8);
            elsif BUS_ADDR_IN(3 downto 0) = x"3" then                   -- wait_cycles / word_length
                BUS_DATA_OUT(15 downto 0) <= ctrl_reg(29 downto 14);
            elsif BUS_ADDR_IN(3 downto 0) = x"B" then                   -- receiving
                BUS_DATA_OUT <= readback;
                blocked      <= '0';
            else
                BUS_ACK_OUT <= '0';
                BUS_UNK_OUT <= '1';
            end if;
        end if;

    end process;


    PROC_FSM : process
    begin
        wait until rising_edge(CLK_IN);
        case fsm_state is
        when IDLE =>

            if start = '1' then
                ram_addr   <= 0;
                word_count <= to_integer(unsigned(ctrl_reg(5 downto 0)));
                bit_count  <= word_length-1;
                time_count <= wait_cycles;
                fsm_state  <= WAIT_STATE;
                spi_cs     <= '1';
                spi_sck    <= '1';
            else
                spi_cs  <= '0';
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
            spi_sdo <= RAM_DATA(bit_count);
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
            spi_cs     <= '0';
            fsm_state  <= TOGGLE_CS_1;
            time_count <= 7;
            end if;
        when TOGGLE_CS_1 =>
            time_count <= time_count - 1;
            if time_count = 0 then
            spi_cs     <= '1';
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
    RAM_BUSY <= '1' when fsm_state /= IDLE else '0';

    spi_sdi <= (SPI_SDI_IN and spi_cs);

    SPI_CS_OUT      <= not ((spi_cs and not override_cs)  xor invert_cs);
    SPI_SDO_OUT     <=      (spi_sdo   and spi_cs and not override_sdo) xor invert_sdo;
    SPI_SCK_OUT     <=      (spi_sck   and not override_sck) xor invert_sck;
  
end architecture;
