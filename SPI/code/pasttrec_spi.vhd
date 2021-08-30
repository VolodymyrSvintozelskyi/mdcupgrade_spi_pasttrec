library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
--use work.clocked_tdc_pkg.all;

use IEEE.math_real."ceil";
use IEEE.math_real."log2";

entity pasttrec_spi is
    generic (
        SPI_BUNCHES             : integer range 1 to 4 := 1;
        SPI_PASTTREC_PER_BUNCH  : positive := 4;
        SPI_CHIP_IDs            : std_logic_vector(2*4*4 - 1 downto 0)
    );
    port(
        CLK             : in std_logic;
        BUS_RX          : in CTRLBUS_RX;
        BUS_TX          : out CTRLBUS_TX;

        RST_IN          : in std_logic;

        SPI_CS_OUT      : out std_logic_vector(SPI_BUNCHES-1 downto 0);
        SPI_SDI_IN      : in  std_logic_vector(SPI_BUNCHES-1 downto 0);
        SPI_SDO_OUT     : out std_logic_vector(SPI_BUNCHES-1 downto 0);
        SPI_SCK_OUT     : out std_logic_vector(SPI_BUNCHES-1 downto 0);
        SPI_RST_OUT     : out std_logic_vector(SPI_BUNCHES-1 downto 0)
    );
end entity;

architecture arch of pasttrec_spi is
    signal mem_write            : std_logic;
    signal mem_addr1            : std_logic_vector (7 downto 0)     := x"00";
    signal mem_data_out1        : std_logic_vector (31 downto 0);
    signal mem_data_in1         : std_logic_vector (31 downto 0);
    signal mem_addr2            : std_logic_vector (7 downto 0)     := x"00";
    signal mem_data_out2        : std_logic_vector (31 downto 0);
    signal mem_addr3            : std_logic_vector (7 downto 0)     := x"00";
    signal mem_data_out3        : std_logic_vector (31 downto 0);
    signal spi_ram_data         : std_logic_vector (31 downto 0);
    --signal clk_inv              : std_logic;

    signal spi_res         : std_logic;
    signal spi_read        : std_logic;
    signal spi_write       : std_logic;
    signal spi_busy        : std_logic;
    signal spi_ack         : std_logic;
    signal spi_unk         : std_logic;
    signal spi_addr        : std_logic_vector (3 downto 0);
    signal spi_data_in     : std_logic_vector (31 downto 0);
    signal spi_data_out    : std_logic_vector (31 downto 0);
    signal spi_ram_busy    : std_logic;
    signal spi_cs_out_intrnl: std_logic;
    signal spi_sdi_in_intrnl: std_logic;
    signal spi_sdo_out_intrnl: std_logic;
    signal spi_sck_out_intrnl: std_logic;

    signal spi_reg_access  : std_logic;
    signal spi_reg_rw      : std_logic; -- 1-read, 0-write
    signal spi_reg_addr    : std_logic_vector(3 downto 0);
    signal spi_reg_data    : std_logic_vector(31 downto 0);
    signal spi_ram_addr    : std_logic_vector(7 downto 0)   := x"00";
    signal spi_ram_offset  : integer range 0 to 63;

    signal spi_active_bunch             : std_logic_vector(SPI_BUNCHES - 1 downto 0) := (others => '0');
    signal spi_active_bunch_sc          : std_logic_vector(SPI_BUNCHES - 1 downto 0) := (others => '0');
    signal spi_active_bunch_autoload    : std_logic_vector(SPI_BUNCHES - 1 downto 0) := (others => '0');

    signal sc_ram_access   : std_logic;
    signal sc_unknown      : std_logic;
    signal sc_busy         : std_logic;
    signal sc_spi_access   : std_logic;
    signal sc_ack          : std_logic;
    signal sc_reset_req    : std_logic;

    signal autoload_chipid : integer range 0 to SPI_BUNCHES*SPI_PASTTREC_PER_BUNCH - 1;
    signal autoload_en     : std_logic;
    signal autoload_num    : integer range 0 to 63;
    signal autoload_addr   : std_logic_vector(7 downto 0);

    signal load_chipid     : integer range 0 to SPI_BUNCHES*SPI_PASTTREC_PER_BUNCH - 1;
    signal load_all        : std_logic;
    signal load_trigger    : std_logic;
    signal load_num        : integer range 0 to 63;
    signal load_addr       : std_logic_vector(7 downto 0);
    signal load_past_id    : integer range 0 to SPI_BUNCHES*SPI_PASTTREC_PER_BUNCH - 1;

    signal spi_fsm_control      : std_logic := '0';
    signal spi_fsm_control_addr : std_logic_vector(7 downto 0) := x"00";
    signal spi_fsm_control_chipid       : std_logic_vector(1 downto 0) := "00";
    signal spi_fsm_control_chipid_en    : std_logic := '0';

    type spi_fsm_t is (RESET, SPI_CONF, IDLE, PASTTREC_RESET_PHASE1, PASTTREC_RESET_PHASE2, PASTTREC_RESET_PHASE3, PASTTREC_RESET_PHASE4, PASTTREC_RESET_PHASE5, SPI_REGS_ACCESS, PASTTREC_PREAUTOLOAD, PASTTREC_AUTOLOAD_CONF1, PASTTREC_AUTOLOAD_CONF2, PASTTREC_AUTOLOAD, PASTTREC_AUTOLOAD_WAIT1, PASTTREC_AUTOLOAD_WAIT2, PASTTREC_AUTOLOAD_NEXT, PASTTREC_LOAD, PASTTREC_LOAD_WAIT1, PASTTREC_LOAD_WAIT2);
    signal spi_fsm_state            : spi_fsm_t     := RESET;

    type sc_fsm_t is (IDLE,WAIT_FOR_SPI, WAIT_FOR_RAM);
    signal sc_fsm_state             : sc_fsm_t      := IDLE;

    constant PASTTREC_CMD_WIDTH     :   integer :=  19;
    constant PASTTREC_WAIT_CYCLES   :   integer :=  7;
begin

    mem_addr3   <= std_logic_vector(to_unsigned(spi_ram_offset + to_integer(unsigned(spi_ram_addr)), 8)) when ( spi_fsm_control = '0' ) else std_logic_vector(to_unsigned(spi_ram_offset + to_integer(unsigned(spi_fsm_control_addr)), 8));

    spi_active_bunch    <= spi_active_bunch_sc when spi_fsm_control = '0' else spi_active_bunch_autoload;

    SPI_OUTPUTS_ASSIGMENT: for i in 0 to SPI_BUNCHES - 1 generate
        SPI_CS_OUT(i)  <= spi_cs_out_intrnl     or not spi_active_bunch(i);
        SPI_SCK_OUT(i) <= spi_sck_out_intrnl    or not spi_active_bunch(i);
        SPI_SDO_OUT(i) <= spi_sdo_out_intrnl    or not spi_active_bunch(i);
    end generate SPI_OUTPUTS_ASSIGMENT;
    spi_sdi_in_intrnl   <= or_all(spi_active_bunch and SPI_SDI_IN);

    SPI_FSM:   process
        variable tmp    : std_logic_vector(31 downto 0) := (others => '0');
    begin
        wait until rising_edge(CLK);
        spi_res         <= '0';
        spi_read        <= '0';
        spi_write       <= '0';
        spi_addr        <= x"0";
        spi_data_in     <= (others => '0');
        --mem_addr2       <= (others => '0');
        SPI_RST_OUT     <= (others => '1');

        case spi_fsm_state is
            when RESET      =>
                spi_res     <=  '1';
                spi_fsm_state   <=  SPI_CONF;
                spi_fsm_control<= '1';
                spi_active_bunch_autoload <= (others => '1');
            when SPI_CONF   =>  -- word_length 19
                spi_write   <= '1';
                spi_addr    <= x"1";
                tmp         := (others => '0');
                tmp(29 downto 20)   := std_logic_vector(to_unsigned(PASTTREC_WAIT_CYCLES, 10));
                tmp(19 downto 14)   := std_logic_vector(to_unsigned(PASTTREC_CMD_WIDTH, 6));
                spi_data_in <= tmp;
                spi_fsm_state   <=  PASTTREC_RESET_PHASE1;
            when PASTTREC_RESET_PHASE1 =>
                SPI_RST_OUT <= (others => '0');
                spi_write       <= '1';
                spi_addr        <= x"A";
                spi_data_in     <= (others => '0');
                spi_data_in (7 downto 0)    <= "01000001";
                spi_fsm_control_addr    <= x"00";
                spi_fsm_state   <= PASTTREC_RESET_PHASE2;
            when PASTTREC_RESET_PHASE2 =>
                SPI_RST_OUT <= (others => '0');
                if spi_ram_busy = '1' then
                    spi_fsm_state <= PASTTREC_RESET_PHASE3;
                end if;
            when PASTTREC_RESET_PHASE3 =>
                SPI_RST_OUT <= (others => '0');
                if spi_ram_busy = '0' then
                    spi_write   <= '1';
                    spi_addr    <= x"A";
                    spi_data_in <= (others => '0');
                    spi_data_in (7 downto 0) <= "01000001";
                    spi_fsm_state <= PASTTREC_RESET_PHASE4;
                end if;
            when PASTTREC_RESET_PHASE4 =>
                if spi_ram_busy = '1' then
                    spi_fsm_state <= PASTTREC_RESET_PHASE5;
                end if;
            when PASTTREC_RESET_PHASE5 =>
                if spi_ram_busy = '0' then
                    spi_fsm_state <= PASTTREC_PREAUTOLOAD;
                end if;
            when PASTTREC_PREAUTOLOAD  =>
                autoload_chipid <= 0;
                mem_addr2       <= x"02";
                spi_fsm_state   <= PASTTREC_AUTOLOAD_CONF1;
            when PASTTREC_AUTOLOAD_CONF1=>
                spi_fsm_state   <= PASTTREC_AUTOLOAD_CONF2;
            when PASTTREC_AUTOLOAD_CONF2=>
                if autoload_chipid rem 2 = 0 then
                    autoload_addr   <= mem_data_out2(7 downto 0);
                    autoload_num    <= to_integer(unsigned(mem_data_out2(13 downto 8)));
                    autoload_en     <= mem_data_out2(14);
                else
                    autoload_addr   <= mem_data_out2(23 downto 16);
                    autoload_num    <= to_integer(unsigned(mem_data_out2(29 downto 24)));
                    autoload_en     <= mem_data_out2(30);
                end if;
                spi_fsm_state   <= PASTTREC_AUTOLOAD;
            when PASTTREC_AUTOLOAD  =>
                if autoload_en = '1' then
                    spi_fsm_control_addr    <= autoload_addr;
                    spi_write       <= '1';
                    spi_addr        <= x"A";
                    spi_data_in     <= (others => '0');
                    spi_active_bunch_autoload <= (others => '0');
                    spi_active_bunch_autoload(autoload_chipid / SPI_PASTTREC_PER_BUNCH) <= '1';
                    spi_data_in (7 downto 0)    <= "01" & std_logic_vector(to_unsigned(autoload_num,6));
                    spi_fsm_state   <= PASTTREC_AUTOLOAD_WAIT1;
                else
                    spi_fsm_state   <= PASTTREC_AUTOLOAD_NEXT;
                end if;
            when PASTTREC_AUTOLOAD_WAIT1  =>
                if (spi_ram_busy = '1') then
                    spi_fsm_state <= PASTTREC_AUTOLOAD_WAIT2;
                end if;
            when PASTTREC_AUTOLOAD_WAIT2  =>
                if (spi_ram_busy = '0') then
                    spi_fsm_state <= PASTTREC_AUTOLOAD_NEXT;
                end if;
            when PASTTREC_AUTOLOAD_NEXT   =>
                if(autoload_chipid = SPI_PASTTREC_PER_BUNCH * SPI_BUNCHES - 1) then
                    spi_fsm_state <= IDLE;
                    spi_fsm_control <= '0';
                else
                    autoload_chipid <= autoload_chipid + 1;
                    spi_fsm_state   <= PASTTREC_AUTOLOAD_CONF1;
                    if autoload_chipid rem 2 = 1 then
                        mem_addr2 <= std_logic_vector(to_unsigned(to_integer(unsigned(mem_addr2)) + 1,8));
                    end if;
                end if;
            when IDLE       =>
                if spi_reg_access = '1' then
                    spi_fsm_state <= SPI_REGS_ACCESS;
                elsif sc_reset_req = '1' then
                    spi_fsm_state <= RESET;
                elsif load_trigger='1' then
                    load_chipid   <= load_past_id;
                    spi_fsm_control_chipid <= SPI_CHIP_IDs(2*load_past_id + 1 downto 2*load_past_id);
                    spi_fsm_control <= '1';
                    spi_fsm_control_chipid_en <= '1';
                    spi_fsm_control_addr <= load_addr;
                    spi_fsm_state <= PASTTREC_LOAD;
                end if;
            when SPI_REGS_ACCESS =>
                if spi_reg_rw = '1' then
                    spi_read    <= '1';
                else
                    spi_write   <= '1';
                end if;
                spi_addr    <= spi_reg_addr;
                spi_data_in <= spi_reg_data;
                spi_fsm_state <= IDLE;
            when PASTTREC_LOAD  =>
                spi_write <= '1';
                spi_addr        <= x"A";
                spi_data_in     <= (others => '0');
                spi_active_bunch_autoload <= (others => '0');
                spi_active_bunch_autoload(load_chipid / SPI_PASTTREC_PER_BUNCH) <= '1';
                spi_data_in (7 downto 0)    <= "01" & std_logic_vector(to_unsigned(load_num,6));
                spi_fsm_state   <= PASTTREC_LOAD_WAIT1;
            when PASTTREC_LOAD_WAIT1  =>
                if (spi_ram_busy = '1') then
                    spi_fsm_state <= PASTTREC_LOAD_WAIT2;
                end if;
            when PASTTREC_LOAD_WAIT2  =>
                if (spi_ram_busy = '0') then
                    if load_all = '1' and load_chipid /= SPI_BUNCHES * SPI_PASTTREC_PER_BUNCH - 1 then
                        load_chipid <= load_chipid + 1;
                        spi_fsm_control_chipid <= SPI_CHIP_IDs(2*(load_chipid+1) + 1 downto 2*(load_chipid+1));
                        spi_fsm_state <= PASTTREC_LOAD;
                    else
                        spi_fsm_state <= IDLE;
                        spi_fsm_control <= '0';
                        spi_fsm_control_chipid_en   <= '0';
                    end if;
                end if;
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
                elsif   sc_ack           = '1' then
                    BUS_TX.ack      <= '1';
                end if;
            when WAIT_FOR_RAM   =>
                BUS_TX.ack      <= '1';
                BUS_TX.data     <= mem_data_out1;
                sc_fsm_state    <= IDLE;
            when WAIT_FOR_SPI   =>
                if spi_ack = '1' then
                    BUS_TX.ack  <= '1';
                    BUS_TX.data <= spi_data_out;
                    sc_fsm_state<= IDLE;
                elsif spi_busy = '1' then
                    BUS_TX.nack <= '1';
                    BUS_TX.data <= spi_data_out;
                    sc_fsm_state<= IDLE;
                elsif spi_unk  = '1' then
                    BUS_TX.unknown  <= '1';
                    BUS_TX.data <= spi_data_out;
                    sc_fsm_state    <= IDLE;
                end if;
            when others         =>
                sc_fsm_state    <= IDLE;
        end case;
        if RST_IN = '1' or spi_fsm_state = RESET then
            sc_fsm_state <= IDLE;
        end if;
    end process SLOW_CTRL_FSM;

    SPI_MEMORY_BUS: process(mem_data_out3, spi_fsm_control_chipid_en, spi_fsm_control_chipid)
    begin
        spi_ram_data <= mem_data_out3;
        if spi_fsm_control_chipid_en = '1' then
            spi_ram_data(14 downto 13) <= spi_fsm_control_chipid;
        end if;
    end process SPI_MEMORY_BUS;

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
            dout2 => mem_data_out2,
            a3    => mem_addr3,
            dout3 => mem_data_out3
        );

    SPI_INTERFACE: entity work.spi_ltc2600_simpl
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
            BUS_UNK_OUT     =>  spi_unk,
            BUS_ADDR_IN     =>  spi_addr,
            BUS_DATA_IN     =>  spi_data_in,
            BUS_DATA_OUT    =>  spi_data_out,
            SPI_CS_OUT      =>  spi_cs_out_intrnl,
            SPI_SDI_IN      =>  spi_sdi_in_intrnl,
            SPI_SDO_OUT     =>  spi_sdo_out_intrnl,
            SPI_SCK_OUT     =>  spi_sck_out_intrnl,
            RAM_BUSY        =>  spi_ram_busy,
            RAM_OFFSET      =>  spi_ram_offset,
            RAM_DATA        =>  spi_ram_data
        );

    SLOW_CONTROL : process
        constant PAST_ID_WIDTH : integer  := integer(ceil(log2(real(SPI_BUNCHES * SPI_PASTTREC_PER_BUNCH))));
        variable past_id       : std_logic_vector(PAST_ID_WIDTH - 1 downto 0);
        variable active_bunches: std_logic_vector(SPI_BUNCHES-1 downto 0);
        variable active_chip_id: std_logic_vector(1 downto 0);
    begin
        wait until rising_edge(CLK);
        mem_addr1       <= x"00";
        mem_write       <= '0';
        mem_data_in1    <= x"00000000";

        sc_ram_access   <= '0';
        sc_unknown      <= '0';
        sc_busy         <= '0';
        sc_ack          <= '0';
        sc_spi_access   <= '0';
        sc_reset_req    <= '0';

        spi_reg_access  <= '0';

        load_trigger    <= '0';

        if sc_fsm_state = IDLE then
            if BUS_RX.write = '1' then
                --BUS_TX.ack  <= '1';
                if spi_fsm_state = IDLE then
                    if BUS_RX.addr(15 downto 8) = x"a0" then            -- MEMORY
                        if BUS_RX.addr = x"a001" and spi_ram_busy = '1' then
                            sc_busy <= '1';
                        else
                            mem_addr1       <= BUS_RX.addr (7 downto 0);
                            mem_data_in1    <= BUS_RX.data;
                            mem_write       <= '1';
                            sc_ram_access   <= '1';
                        end if;
                    elsif BUS_RX.addr(15 downto 8) = x"a1" and BUS_RX.addr(7 downto 4) = x"0" then            -- SPI REGISTERS
                        if spi_ram_busy = '1' and BUS_RX.addr(3 downto 0) /= "0000" then
                            sc_busy <= '1';
                        else
                            spi_reg_access  <= '1';
                            spi_reg_rw      <= '0';
                            spi_reg_addr    <= BUS_RX.addr (3 downto 0);
                            spi_reg_data    <= BUS_RX.data;
                            sc_spi_access   <= '1';
                        end if;
                    elsif BUS_RX.addr(15 downto 8) = x"a2" and or_all(BUS_RX.addr(7 downto 4 + PAST_ID_WIDTH)) = '0' then         -- PASTTREC REGISTERS
                        if spi_ram_busy = '1' then
                            sc_busy <= '1';
                        else
                            past_id := BUS_RX.addr(7 downto 4);
                            active_bunches := (others => '0');
                            active_bunches(to_integer(unsigned( past_id)) / SPI_PASTTREC_PER_BUNCH) := '1';
                            active_chip_id := SPI_CHIP_IDs( to_integer(unsigned( past_id))*2+1 downto to_integer(unsigned( past_id))*2 );

                            spi_active_bunch_sc <= active_bunches;

                            mem_addr1       <= x"01";
                            mem_write       <= '1';
                            mem_data_in1    <= (others => '0');
                            mem_data_in1(7 downto 0)    <= BUS_RX.data(7 downto 0);
                            mem_data_in1(11 downto 8)   <= BUS_RX.addr(3 downto 0);
                            mem_data_in1(12)            <= '0';
                            mem_data_in1(14 downto 13)  <= active_chip_id;
                            mem_data_in1(18 downto 15)  <= "1010";

                            spi_ram_addr    <= x"01";

                            spi_reg_access  <= '1';
                            spi_reg_rw      <= '0';
                            spi_reg_addr    <= x"A";
                            spi_reg_data    <= (others => '0');
                            spi_reg_data(7 downto 0)    <= "01000001";
                            sc_spi_access   <= '1';
                        end if;

                    elsif BUS_RX.addr(15 downto 8) = x"aA" then         -- CMD
                        if BUS_RX.addr(7 downto 0) = x"00" then
                            sc_reset_req    <= '1';
                            sc_ack          <= '1';
                        elsif BUS_RX.addr(2 downto 0) = o"1" then
                            load_trigger    <= '1';
                            load_all<= BUS_RX.addr(7);
                            if BUS_RX.addr(7) = '1' then
                                load_past_id <= 0;
                            else
                                load_past_id <= to_integer(unsigned(BUS_RX.addr(6 downto 3)));
                            end if;
                            load_addr   <= BUS_RX.data(7 downto 0);
                            load_num    <= to_integer(unsigned( BUS_RX.data(13 downto 8) ));
                            sc_ack <= '1';
                        else
                            sc_unknown <= '1';
                        end if;
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
                elsif BUS_RX.addr(15 downto 8) = x"a1" then
                    spi_reg_access  <= '1';
                    spi_reg_rw      <= '1';
                    spi_reg_addr    <= BUS_RX.addr (3 downto 0);
                    sc_spi_access   <= '1';
                else
                    sc_unknown      <= '1';
                end if;
            end if;
        end if;
    end process;

end architecture;
