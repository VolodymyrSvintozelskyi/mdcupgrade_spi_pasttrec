library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;


library work;
use work.trb_net_std.all;
use work.clocked_tdc_pkg.all;

entity tb_loader is
end tb_loader;

architecture tb of tb_loader is
    signal CLK    : std_logic;
    signal BUS_RX : CTRLBUS_RX;
    signal BUS_TX : CTRLBUS_TX;

    signal RST_IN : std_logic;

    signal SPI_CS_OUT      : std_logic_vector(15 downto 0);
    signal SPI_SDI_IN      : std_logic_vector(15 downto 0);
    signal SPI_SDO_OUT     : std_logic_vector(15 downto 0);
    signal SPI_SCK_OUT     : std_logic_vector(15 downto 0);
    signal SPI_CLR_OUT     : std_logic_vector(15 downto 0);

    constant TbPeriod : time := 5 ns; -- EDIT Put right period here
    signal TbSimEnded : std_logic := '0';

    type spi_hist_t is array(0 to 100) of std_logic_vector(18 downto 0);
    signal spi_hist        : spi_hist_t;
    signal spi_hist_ind    : integer := 0;

    procedure echo (arg : in string := "") is
    begin
        std.textio.write(std.textio.output, arg);
    end procedure echo;

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
begin

    dut : entity work.loader
    port map (
                CLK    => CLK,
                BUS_RX => BUS_RX,
                BUS_TX => BUS_TX,

                RST_IN => RST_IN,

                SPI_CS_OUT  =>  SPI_CS_OUT,
                SPI_SDI_IN  =>  SPI_SDI_IN,
                SPI_SDO_OUT =>  SPI_SDO_OUT,
                SPI_SCK_OUT =>  SPI_SCK_OUT,
                SPI_CLR_OUT =>  SPI_CLR_OUT
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

    stimuli : process
        variable data           : std_logic_vector(18 downto 0);
        variable num_of_errors  : integer := 0;
    begin
        -- EDIT Adapt initialization as needed
        BUS_RX.data     <= (others => '0');
        BUS_RX.addr     <= (others => '0');
        BUS_RX.write    <= '0';
        BUS_RX.read     <= '0';
        BUS_RX.timeout  <= '0';
        RST_IN          <= '1';
        SPI_SDI_IN      <= (others => '1');

        wait for 4 * TbPeriod;
        wait until falling_edge(CLK);
        RST_IN          <= '0';

        wait for 10 * TbPeriod;
        wait until falling_edge(CLK);

        echo ("MEMORY CHECK ---------------------------" & lf);
        for i in 0 to 16 loop
            BUS_RX.read <= '1';
            BUS_RX.addr <= x"a0" & std_logic_vector(to_unsigned(i, 8));
            wait until falling_edge(CLK);
            BUS_RX.read <= '0';
            wait until falling_edge(CLK);
            wait until falling_edge(CLK);
            echo( "Memory addr=" & integer'image(i) & "  DATA: " & to_hstring(BUS_TX.data) & lf);
            assert BUS_TX.data = ram(i) and BUS_TX.ack = '1' and BUS_TX.nack = '0' report "MEMORY ERROR";
            if BUS_TX.data /= ram(i) or BUS_TX.ack /= '1' or BUS_TX.nack /= '0' then
                num_of_errors := num_of_errors + 1;
            end if;
            wait until falling_edge(CLK);
            wait until falling_edge(CLK);
        end loop;
        echo ("ERRORS: " & integer'image(num_of_errors) & "------------" & lf & lf & lf);

        wait for 5 * TbPeriod;

        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a120";
        BUS_RX.data  <= x"00000001";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';

        wait for 5 * TbPeriod;

        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a110";
        BUS_RX.data  <= x"00002300";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';

        wait for 100*TbPeriod;

        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a110";
        BUS_RX.data  <= x"FFFFFFFF";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';

        wait for 10*TbPeriod;

        wait until falling_edge(CLK);
        BUS_RX.read <= '1';
        BUS_RX.addr <= x"a000";
        wait until falling_edge(CLK);
        BUS_RX.read <= '0';
        wait until falling_edge(CLK);

        wait for 10*TbPeriod;

        wait until falling_edge(CLK);
        BUS_RX.read <= '1';
        BUS_RX.addr <= x"a501";
        wait until falling_edge(CLK);
        BUS_RX.read <= '0';
        wait until falling_edge(CLK);

        wait for 10*TbPeriod;

        wait until falling_edge(CLK);
        BUS_RX.read <= '1';
        BUS_RX.addr <= x"a100";
        wait until falling_edge(CLK);
        BUS_RX.read <= '0';
        wait until falling_edge(CLK);


        wait for 400*TbPeriod;

        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a100";
        BUS_RX.data  <= x"00000000";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';

        wait for 500*TbPeriod;
        wait until SPI_CS_OUT(0) = '1';
        wait for 100*TbPeriod;

        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a100";
        BUS_RX.data  <= x"00000020";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';

        wait for 500*TbPeriod;
        wait until SPI_CS_OUT(0) = '1';
        wait for 100*TbPeriod;

        echo( lf & lf & lf & "----------------------------" &lf&"SPI history:"&lf);
        echo("             HEX | HEADER | ADDR | R/W | REG  | DATA" & lf );
        for i in 0 to spi_hist_ind - 1 loop
            data := spi_hist(i);
            echo( "SPI CATCH: " & to_hstring(data) & " |  " & to_string(data(18 downto 15)) & "  |  " & to_string(data(14 downto 13)) & "  |  " & to_string(data(12)) & "  | " & to_string(data(11 downto 8)) & " | " & to_string(data(7 downto 0))  & lf);
        end loop;

        wait;
    end process;

    SPI_CATCH: process
        variable data : std_logic_vector (18 downto 0);
    begin
        wait until falling_edge(SPI_CS_OUT(0));
        loop
            for i in 18 downto 0 loop
                wait until rising_edge(SPI_SCK_OUT(0));
                data (i) := SPI_SDO_OUT(0);
            end loop;
            report "SPI CATCH: " & to_hstring(data) & " | " & to_string(data(18 downto 15)) & " | ADDR " & to_string(data(14 downto 13)) & " | R/W " & to_string(data(12)) & " | REG " & to_string(data(11 downto 8)) & " | DATA " & to_string(data(7 downto 0));
            spi_hist(spi_hist_ind) <= data;
            spi_hist_ind <= spi_hist_ind + 1;
            wait until rising_edge(SPI_CS_OUT(0)) OR falling_edge(SPI_SCK_OUT(0));
            exit when SPI_CS_OUT(0) = '1';
        end loop;
    end process;

end tb;

-- Configuration block below is required by some simulators. Usually no need to edit.

configuration cfg_tb_loader of tb_loader is
    for tb
    end for;
end cfg_tb_loader;
