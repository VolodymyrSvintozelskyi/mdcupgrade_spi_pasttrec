library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.clocked_tdc_pkg.all;

entity loader is
    port(
        CLK             : in std_logic;
        BUS_RX          : in CTRLBUS_RX;
        BUS_TX          : out CTRLBUS_TX;

        RST_IN          : in std_logic;

        SPI_CS_OUT      : out std_logic_vector(15 downto 0);
        SPI_SDI_IN      : in  std_logic_vector(15 downto 0);
        SPI_SDO_OUT     : out std_logic_vector(15 downto 0);
        SPI_SCK_OUT     : out std_logic_vector(15 downto 0);
        SPI_CLR_OUT     : out std_logic_vector(15 downto 0)
    );
end entity;

architecture arch of loader is
    signal mem_write            : std_logic;
    signal mem_addr1            : std_logic_vector (7 downto 0)     := x"00";
    signal mem_data_out1        : std_logic_vector (31 downto 0);
    signal mem_data_in1         : std_logic_vector (31 downto 0);
    signal mem_addr2            : std_logic_vector (7 downto 0)     := x"00";
    signal mem_data_out2        : std_logic_vector (31 downto 0);
    --signal clk_inv              : std_logic;

    signal spi_res         : std_logic;
    signal spi_read        : std_logic;
    signal spi_write       : std_logic;
    signal spi_busy        : std_logic;
    signal spi_ack         : std_logic;
    signal spi_addr        : std_logic_vector (4 downto 0);
    signal spi_data_in     : std_logic_vector (31 downto 0);
    signal spi_data_out    : std_logic_vector (31 downto 0);
    signal spi_cs_reg      : std_logic_vector (15 downto 0);

    signal load_spi        : std_logic;
    signal load_spi_source : std_logic;
    signal load_spi_addr   : std_logic_vector(7 downto 0);
    signal load_spi_counter: integer range 0 to 16;
    signal load_spi_cmd    : std_logic_vector(31 downto 0);

    signal update_cs_reg   : std_logic;

    signal sc_ram_access   : std_logic;
    signal sc_unknown      : std_logic;
    signal sc_busy         : std_logic;
    signal sc_spi_access   : std_logic;
    signal sc_spi_resp_n   : integer range 0 to 15;
    signal sc_spi_resp_curr: integer range 0 to 15;

    type spi_fsm_t is (RESET, SPI_CONF1, SPI_CONF2, SPI_CONF3, SPI_CONF4, SPI_CONF5, SPI_CONF_CS, IDLE, SPI_LOAD_RAM, SPI_LOAD_CMD, SPI_SEND_DATA);
    signal spi_fsm_state            : spi_fsm_t;

    type sc_fsm_t is (IDLE,WAIT_FOR_SPI, WAIT_FOR_RAM);
    signal sc_fsm_state             : sc_fsm_t;

    constant PASTTREC_CMD_WIDTH     :   integer :=  19;
    constant PASTTREC_WAIT_CYCLES   :   integer :=  7;
begin

    SPI_FSM:   process
    begin
        wait until rising_edge(CLK);
        spi_res         <= '0';
        spi_read        <= '0';
        spi_write       <= '0';
        spi_addr        <= '0' & x"0";
        spi_data_in     <= (others => '0');
        mem_addr2       <= (others => '0');

        case spi_fsm_state is
            when RESET      =>
                spi_res     <=  '1';
                spi_fsm_state   <=  SPI_CONF1;
            when SPI_CONF1  =>  -- word_length 19
                spi_write   <= '1';
                spi_addr    <= '1' & x"9";
                spi_data_in <= std_logic_vector(to_unsigned(PASTTREC_CMD_WIDTH, 32));
                spi_fsm_state   <=  SPI_CONF2;
            when SPI_CONF2  =>  -- wait_cycles 7
                spi_write   <= '1';
                spi_addr    <= '1' & x"a";
                spi_data_in <= std_logic_vector(to_unsigned(PASTTREC_WAIT_CYCLES, 32));
                spi_fsm_state   <=  SPI_CONF3;
            when SPI_CONF3  =>  -- sdo no invert no override
                spi_write   <= '1';
                spi_addr    <= '1' & x"5";
                spi_data_in <= (others => '0');
                spi_fsm_state   <=  SPI_CONF4;
            when SPI_CONF4  =>  -- sck no invert no override
                spi_write   <= '1';
                spi_addr    <= '1' & x"6";
                spi_data_in <= (others => '0');
                spi_fsm_state   <=  SPI_CONF5;
            when SPI_CONF5  =>  -- cs no invert no override
                spi_write   <= '1';
                spi_addr    <= '1' & x"7";
                spi_data_in <= (others => '0');
                spi_fsm_state   <=  SPI_CONF_CS;
            when SPI_CONF_CS=>  -- cs_reg
                spi_write   <= '1';
                spi_addr    <= '1' & x"0";
                spi_data_in <= x"0000" & spi_cs_reg;
                spi_fsm_state   <=  IDLE;
            when IDLE       =>
                if load_spi = '1' and load_spi_source = '0' then
                    spi_fsm_state           <= SPI_LOAD_RAM;
                    mem_addr2           <= load_spi_addr;
                    load_spi_counter    <= 0;
                elsif load_spi = '1' and load_spi_source = '1' then
                    spi_fsm_state           <= SPI_LOAD_CMD;
                    load_spi_counter    <= 0;
                elsif update_cs_reg = '1' then
                    spi_fsm_state           <= SPI_CONF_CS;
                end if;
            when SPI_LOAD_RAM   =>
                if load_spi_counter = 16 then
                    spi_fsm_state           <= SPI_SEND_DATA;
                    load_spi_counter    <= 15;
                else
                    load_spi_counter    <= load_spi_counter + 1;
                    mem_addr2           <= std_logic_vector(to_unsigned(to_integer(unsigned(load_spi_addr)) + load_spi_counter + 1, 8));
                end if;
                if load_spi_counter /= 0 then
                    spi_write           <= '1';
                    spi_addr            <= '0' & std_logic_vector(to_unsigned(load_spi_counter-1,4));
                    spi_data_in         <= mem_data_out2;--(mem_data_out2 and x"00007FFF") OR x"00050000";
                end if;
            when SPI_LOAD_CMD   =>
                spi_write           <= '1';
                spi_addr            <= '0' & std_logic_vector(to_unsigned(load_spi_counter,4));
                spi_data_in         <= load_spi_cmd;--(load_spi_cmd and x"00007FFF") OR x"00050000";
                load_spi_counter    <= load_spi_counter + 1;
                spi_fsm_state           <= SPI_SEND_DATA;
            when SPI_SEND_DATA  =>
                spi_write   <= '1';
                spi_addr    <= '1' & x"1" ;
                spi_data_in <= std_logic_vector(to_unsigned(2**(17),32)) OR std_logic_vector(to_unsigned(load_spi_counter, 32));
                spi_fsm_state   <=  IDLE;
            when others     =>
                spi_fsm_state   <= RESET;
        end case;
        if RST_IN = '1' then
            spi_fsm_state <= RESET;
        end if;
    end process SPI_FSM;

    SLOW_CTRL_FSM: process
    begin
        wait until rising_edge(CLK);
        BUS_TX.ack      <= '0';
        BUS_TX.unknown  <= '0';
        BUS_TX.nack     <= '0';
        BUS_TX.wack     <= '0';
        BUS_TX.rack     <= '0';
        BUS_TX.data     <= (others => '0');

        case sc_fsm_state is
            when IDLE           =>
                if      sc_unknown       = '1' then
                    BUS_TX.unknown  <= '1';
                elsif   sc_busy          = '1' then
                    BUS_TX.nack     <= '1';
                elsif   sc_ram_access    = '1' then
                    sc_fsm_state    <= WAIT_FOR_RAM;
                elsif   sc_spi_access    = '1' then
                    sc_fsm_state    <= WAIT_FOR_SPI;
                    sc_spi_resp_curr<= 0;
                end if;
            when WAIT_FOR_RAM   =>
                BUS_TX.ack      <= '1';
                BUS_TX.data     <= mem_data_out1;
                sc_fsm_state    <= IDLE;
            when WAIT_FOR_SPI   =>
                if spi_ack = '1' then
                    if sc_spi_resp_curr + 1 = sc_spi_resp_n then
                        BUS_TX.ack  <= '1';
                        sc_fsm_state<= IDLE;
                    else
                        sc_spi_resp_curr <= sc_spi_resp_curr + 1;
                    end if;
                elsif spi_busy = '1' then
                    BUS_TX.nack <= '1';
                    sc_fsm_state<= IDLE;
                end if;
            when others         =>
                sc_fsm_state    <= IDLE;
        end case;
        if RST_IN = '1' then
            sc_fsm_state <= IDLE;
        end if;
    end process SLOW_CTRL_FSM;

    MEMORY: entity work.ram_dp_preset
        generic map(
            depth   => 8,
            width   => 32,
            initfile=> "../code/memory.hex"
        )
        port map(
            CLK   => CLK,
            wr1   => mem_write,
            a1    => mem_addr1,
            dout1 => mem_data_out1,
            din1  => mem_data_in1,
            a2    => mem_addr2,
            dout2 => mem_data_out2
        );

    SPI_INTERFACE: entity work.spi_ltc2600
        generic map(
            BITS            =>  PASTTREC_CMD_WIDTH,
            WAITCYCLES      =>  PASTTREC_WAIT_CYCLES
        ) port map(
            CLK_IN          =>  CLK,
            RESET_IN        =>  spi_res,
            BUS_READ_IN     =>  spi_read,
            BUS_WRITE_IN    =>  spi_write,
            BUS_BUSY_OUT    =>  spi_busy,
            BUS_ACK_OUT     =>  spi_ack,
            BUS_ADDR_IN     =>  spi_addr,
            BUS_DATA_IN     =>  spi_data_in,
            BUS_DATA_OUT    =>  spi_data_out,
            -- TODO: Connect SPI ports:
            SPI_CS_OUT      =>  SPI_CS_OUT,
            SPI_SDI_IN      =>  SPI_SDI_IN,
            SPI_SDO_OUT     =>  SPI_SDO_OUT,
            SPI_SCK_OUT     =>  SPI_SCK_OUT,
            SPI_CLR_OUT     =>  SPI_CLR_OUT
        );

    SLOW_CONTROL : process
    begin
        wait until rising_edge(CLK);
        mem_addr1       <= x"00";
        mem_write       <= '0';
        mem_data_in1    <= x"00000000";

        load_spi        <= '0';
        update_cs_reg   <= '0';

        sc_ram_access   <= '0';
        sc_unknown      <= '0';
        sc_busy         <= '0';
        sc_spi_access   <= '0';

        if sc_fsm_state = IDLE then
            if BUS_RX.write = '1' then
                --BUS_TX.ack  <= '1';
                if spi_fsm_state = IDLE then
                    if BUS_RX.addr(15 downto 8) = x"a0" then            -- MEMORY
                        mem_addr1       <= BUS_RX.addr (7 downto 0);
                        mem_data_in1    <= BUS_RX.data;
                        mem_write       <= '1';
                        sc_ram_access   <= '1';
                    elsif BUS_RX.addr(15 downto 8) = x"a1" then         -- CMD_SPI
                        sc_spi_access   <= '1';
                        case BUS_RX.addr(7 downto 4) is
                            when x"0"           =>              -- INIT PASTTREC FROM MEMORY
                                load_spi        <= '1';
                                load_spi_source <= '0';
                                load_spi_addr   <= BUS_RX.data(7 downto 0);
                                sc_spi_resp_n   <= 15;
                            when x"1"           =>              -- SEND CMD TO PASTTREC
                                load_spi        <= '1';
                                load_spi_source <= '1';
                                load_spi_cmd    <= BUS_RX.data;
                                sc_spi_resp_n   <= 1;
                            when x"2"           =>              -- edit cs_reg
                                spi_cs_reg      <= BUS_RX.data(15 downto 0);
                                update_cs_reg   <= '1';
                                sc_spi_resp_n   <= 1;
                            when others         =>
                                sc_spi_access   <= '0';
                                sc_unknown      <= '1';
                        end case;
                    else
                        sc_unknown <= '1';
                    end if;
                else
                    sc_busy   <= '1';
                end if;
            elsif BUS_RX.read = '1' then
                if BUS_RX.addr(15 downto 8) = x"a0" then
                    mem_addr1       <= BUS_RX.addr(7 downto 0);
                    sc_ram_access   <= '1';
                else
                    sc_unknown      <= '1';
                end if;
            end if;
        end if;
    end process;

end architecture;
