library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--use work.spi_ltc2600.all;

entity basic_tb is
end entity;

architecture arch of basic_tb is
    signal CLK_IN: std_logic;
    signal RESET_IN: std_logic;
    signal BUS_READ_IN: std_logic;
    signal BUS_WRITE_IN: std_logic;
    signal BUS_BUSY_OUT: std_logic;
    signal BUS_ACK_OUT: std_logic;
    signal BUS_ADDR_IN: std_logic_vector(4 downto 0);
    signal BUS_DATA_IN: std_logic_vector(31 downto 0);
    signal BUS_DATA_OUT: std_logic_vector(31 downto 0);
    signal SPI_CS_OUT: std_logic_vector(15 downto 0);
    signal SPI_SDI_IN: std_logic_vector(15 downto 0);
    signal SPI_SDO_OUT: std_logic_vector(15 downto 0);
    signal SPI_SCK_OUT: std_logic_vector(15 downto 0);
    signal SPI_CLR_OUT: std_logic_vector(15 downto 0) ;

    constant clock_period: time := 10 ns;
begin
    DUT: entity work.spi_ltc2600
        port map (
            CLK_IN       => CLK_IN,
            RESET_IN     => RESET_IN,
            BUS_READ_IN  => BUS_READ_IN,
            BUS_WRITE_IN => BUS_WRITE_IN,
            BUS_BUSY_OUT => BUS_BUSY_OUT,
            BUS_ACK_OUT  => BUS_ACK_OUT,
            BUS_ADDR_IN  => BUS_ADDR_IN,
            BUS_DATA_IN  => BUS_DATA_IN,
            BUS_DATA_OUT => BUS_DATA_OUT,
            SPI_CS_OUT   => SPI_CS_OUT,
            SPI_SDI_IN   => SPI_SDI_IN,
            SPI_SDO_OUT  => SPI_SDO_OUT,
            SPI_SCK_OUT  => SPI_SCK_OUT,
            SPI_CLR_OUT  => SPI_CLR_OUT );

    clocking: process
    begin
        CLK_IN <= '1';
        wait for clock_period/2;
        CLK_IN <= '0';
        wait for clock_period/2;
    end process;

    stimulus: process
    begin
        BUS_READ_IN <= '0';
        BUS_WRITE_IN <= '0';

        RESET_IN <= '1';
        wait for 5*clock_period;
        RESET_IN <= '0';
        wait until falling_edge(CLK_IN);
        for i in 0 to 11 loop
            wait until falling_edge(CLK_IN);
            BUS_READ_IN <= '1';
            BUS_ADDR_IN <= '1' & std_logic_vector(to_unsigned(i, 4));
            wait until falling_edge(CLK_IN);
            BUS_READ_IN <= '0';
            wait for 2*clock_period;
            wait until falling_edge(CLK_IN);
        end loop;
        wait until falling_edge(CLK_IN);
        BUS_WRITE_IN <= '1';
        BUS_ADDR_IN <= "10000";
        BUS_DATA_IN <= x"0000" & "1010101010101010";
        wait until falling_edge(CLK_IN);
        BUS_WRITE_IN <= '0';
        BUS_DATA_IN <= x"00000000";
        BUS_READ_IN <= '1';
        -- Put initialisation code here
        wait for 20*clock_period;
    end process;
end architecture;

