library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;
use IEEE.math_real.all;

library work;
use work.trb_net_std.all;
--use work.clocked_tdc_pkg.all;

entity system_testbench is
end entity;

architecture tb of system_testbench is
    signal CLK    : std_logic;
    signal BUS_RX : CTRLBUS_RX;
    signal BUS_TX : CTRLBUS_TX;

    signal RST_IN : std_logic;

    signal SPI_CS_OUT      : std_logic_vector(2 downto 0);
    signal SPI_SDI_IN      : std_logic_vector(2 downto 0);
    signal SPI_SDO_OUT     : std_logic_vector(2 downto 0);
    signal SPI_SCK_OUT     : std_logic_vector(2 downto 0);
    signal SPI_RST_OUT     : std_logic_vector(2 downto 0);

    constant TbPeriod : time := 5 ns; -- EDIT Put right period here
    signal TbSimEnded : std_logic := '0';

    type ram_t is array(0 to 2**8-1) of std_logic_vector(32-1 downto 0);
    impure function read_from_file(filename : string) return ram_t is
        file text_file      : text open read_mode is filename;
        variable text_line  : line;
        variable mem        : ram_t;
    begin
        for i in 0 to 2**8-1 loop
            readline(text_file, text_line);
            hread(text_line, mem(i));
        end loop;
        return mem;
    end function;
    SIGNAL ram : ram_t := read_from_file("../code/memory.hex");

    procedure echo (arg : in string := "") is
    begin
        std.textio.write(std.textio.output, arg);
    end procedure echo;

    signal wait_for_responce : std_logic_vector(2 downto 0);
    signal wait_en           : std_logic := '0';
    signal wait_cnt          : integer :=0;
    signal wait_end          : std_logic := '0';
    signal wait_error        : std_logic := '0';
    constant max_wait_cnt    : integer := 5;
begin

    dut : entity work.pasttrec_spi
    generic map(
        SPI_BUNCHES => 3,
        SPI_PASTTREC_PER_BUNCH => 2,
        SPI_CHIP_IDs => (11 downto 0 => "100110011001", others => '0')
    )port map (
                CLK    => CLK,
                BUS_RX => BUS_RX,
                BUS_TX => BUS_TX,

                RST_IN => RST_IN,

                SPI_CS_OUT  =>  SPI_CS_OUT,
                SPI_SDI_IN  =>  SPI_SDI_IN,
                SPI_SDO_OUT =>  SPI_SDO_OUT,
                SPI_SCK_OUT =>  SPI_SCK_OUT,
                SPI_RST_OUT =>  SPI_RST_OUT
              );

    -- Clock generation
    clocking: process
    begin
        CLK <= '1';
        wait for TbPeriod / 2;
        CLK <= '0';
        wait for TbPeriod / 2;
        if TbSimEnded = '1' then
            wait;
        end if;
    end process clocking;


    PASTTREC1: entity work.pasttrec_test_module
    generic map(
        chipid => "01"
    )port map(
            SCK => SPI_SCK_OUT(0),
            SDO => SPI_SDO_OUT(0),
            SDI => SPI_SDI_IN(0),
            RST => SPI_RST_OUT(0)
        );

    PASTTREC2: entity work.pasttrec_test_module
    generic map(
        chipid => "10"
    )port map(
            SCK => SPI_SCK_OUT(0),
            SDO => SPI_SDO_OUT(0),
            SDI => SPI_SDI_IN(0),
            RST => SPI_RST_OUT(0)
        );

    PASTTREC3: entity work.pasttrec_test_module
    generic map(
        chipid => "01"
    )port map(
            SCK => SPI_SCK_OUT(1),
            SDO => SPI_SDO_OUT(1),
            SDI => SPI_SDI_IN(1),
            RST => SPI_RST_OUT(1)
        );

    PASTTREC4: entity work.pasttrec_test_module
    generic map(
        chipid => "10"
    )port map(
            SCK => SPI_SCK_OUT(1),
            SDO => SPI_SDO_OUT(1),
            SDI => SPI_SDI_IN(1),
            RST => SPI_RST_OUT(1)
        );

    PASTTREC5: entity work.pasttrec_test_module
    generic map(
        chipid => "01"
    )port map(
            SCK => SPI_SCK_OUT(2),
            SDO => SPI_SDO_OUT(2),
            SDI => SPI_SDI_IN(2),
            RST => SPI_RST_OUT(2)
        );

    PASTTREC6: entity work.pasttrec_test_module
    generic map(
        chipid => "10"
    )port map(
            SCK => SPI_SCK_OUT(2),
            SDO => SPI_SDO_OUT(2),
            SDI => SPI_SDI_IN(2),
            RST => SPI_RST_OUT(2)
        );


    stimuli : process
        variable num_of_errors : integer := 0;
    begin
        wait for 10*TbPeriod;
        RST_IN  <= '1';
        wait for 10*TbPeriod;
        RST_IN  <= '0';
        wait until <<signal .system_testbench.dut.spi_fsm_control : std_logic>> = '0';

        wait for 1000*TbPeriod;


        echo("Load to 2 chip"&lf);
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aA" & "0" & "0001" & o"1";
        BUS_RX.data  <= x"0000" & x"0F" & x"50";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';
        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        wait for 10*TbPeriod;
        wait until <<signal .system_testbench.dut.spi_fsm_control : std_logic>> = '0';
        wait for 100*TbPeriod;

        echo("Load to 3 chip"&lf);
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aA" & "0" & "0010" & o"1";
        BUS_RX.data  <= x"0000" & x"0F" & x"60";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';
        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        wait for 10*TbPeriod;
        wait until <<signal .system_testbench.dut.spi_fsm_control : std_logic>> = '0';
        wait for 100*TbPeriod;

        echo("Load to 1 chip"&lf);
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aA" & "0" & "0000" & o"1";
        BUS_RX.data  <= x"0000" & x"0F" & x"40";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';
        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        wait for 10*TbPeriod;
        wait until <<signal .system_testbench.dut.spi_fsm_control : std_logic>> = '0';
        wait for 100*TbPeriod;

        echo("Load to 4 chip"&lf);
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aA" & "0" & "0011" & o"1";
        BUS_RX.data  <= x"0000" & x"0F" & x"70";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';
        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        wait for 10*TbPeriod;
        wait until <<signal .system_testbench.dut.spi_fsm_control : std_logic>> = '0';

        echo("Load to 5 chip"&lf);
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aA" & "0" & "0100" & o"1";
        BUS_RX.data  <= x"0000" & x"0F" & x"80";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';
        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        wait for 10*TbPeriod;
        wait until <<signal .system_testbench.dut.spi_fsm_control : std_logic>> = '0';

        echo("Load to 6 chip"&lf);
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aA" & "0" & "0101" & o"1";
        BUS_RX.data  <= x"0000" & x"0F" & x"90";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';
        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        wait for 10*TbPeriod;
        wait until <<signal .system_testbench.dut.spi_fsm_control : std_logic>> = '0';


        wait for 1000*TbPeriod;

        -------------MEMORY AUTO START CLEAN
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a002";
        BUS_RX.data  <= x"00000000";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';

        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------

        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a003";
        BUS_RX.data  <= x"00000000";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';

        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        ------------------RESET
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aa00";
        BUS_RX.data  <= x"00000000";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';

        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        wait for 10*TbPeriod;
        wait until <<signal .system_testbench.dut.spi_fsm_control : std_logic>> = '0';
        wait for 10*TbPeriod;

         report ("Load to all chips"&lf);
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aA" & x"81";
        BUS_RX.data  <= x"0000" & x"FF" & x"10";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';
        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        wait for 10*TbPeriod;
        wait until <<signal .system_testbench.dut.spi_fsm_control : std_logic>> = '0';

        wait for 1000*TbPeriod;

        report ("Read attempt"&lf);
        wait until falling_edge(CLK);
        BUS_RX.read <= '1';
        BUS_RX.addr  <= x"a1" & x"0B";
        BUS_RX.data  <= x"00000000";
        wait until falling_edge(CLK);
        BUS_RX.read <= '0';
        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        report ("Responce: " & to_hstring( BUS_TX.data) & lf);

        TbSimEnded <= '1';
        echo (lf & "-------------" & lf & "END | ERRORS: " & integer'image(num_of_errors) &lf & "-------------" & lf);
        wait;
    end process;



    responce_proc : process
        variable tmp : std_logic_vector(2 downto 0);
    begin
        wait until falling_edge(CLK);
        wait_end <= '0';
        wait_error <= '0';

        if wait_en = '0' then
            wait_cnt <= 0;
        else
            assert wait_cnt < max_wait_cnt report "Timeout violated!";
            if not(wait_cnt < max_wait_cnt) then
                wait_end <= '1';
                wait_error <= '1';
            elsif (BUS_TX.ack = '1' or BUS_TX.nack = '1' or BUS_TX.unknown = '1') then
                tmp := BUS_TX.ack & BUS_TX.nack & BUS_TX.unknown;
                assert (BUS_TX.ack = wait_for_responce(2) and BUS_TX.nack = wait_for_responce(1) and BUS_TX.unknown = wait_for_responce(0)) report "Incorrect answer. Shoud be: " & to_string(wait_for_responce) & " actual is: " & to_string(tmp);
                if not (BUS_TX.ack = wait_for_responce(2) and BUS_TX.nack = wait_for_responce(1) and BUS_TX.unknown = wait_for_responce(0)) then
                    wait_end <= '1';
                    wait_error <= '1';
                else
                    wait_end <= '1';
                end if;
            else
                wait_cnt <= wait_cnt + 1;
            end if;
        end if;
    end process;
end architecture;
