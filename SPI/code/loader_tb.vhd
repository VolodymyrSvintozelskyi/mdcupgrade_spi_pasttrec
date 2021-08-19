library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

    constant TbPeriod : time := 20 ns; -- EDIT Put right period here
    signal TbSimEnded : std_logic := '0';
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

        for i in 0 to 16 loop
            BUS_RX.read <= '1';
            BUS_RX.addr <= x"a0" & std_logic_vector(to_unsigned(i, 8));
            wait until falling_edge(CLK);
            BUS_RX.read <= '0';
            --wait until falling_edge(CLK);
            report "Memory addr=" & integer'image(i) & "  DATA: " & to_hstring(BUS_TX.data);
            wait until falling_edge(CLK);
            wait until falling_edge(CLK);
        end loop;

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

        wait for 500*TbPeriod;

        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a100";
        BUS_RX.data  <= x"00000000";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';

        wait for 5*TbPeriod;
        -- Stop the clock and hence terminate the simulation
        --TbSimEnded <= '1';
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
            report "SPI CATCH: " & to_hstring(data) & " | ADDR " & to_string(data(14 downto 13)) & " | R/W " & to_string(data(12)) & " | REG " & to_string(data(11 downto 8)) & " | DATA " & to_string(data(7 downto 0));
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
