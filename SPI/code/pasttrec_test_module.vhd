library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pasttrec_test_module is
    generic (
        chipid  : std_logic_vector(1 downto 0)
    );
    port(
        SCK : in std_logic;
        SDO : in std_logic;
        SDI : out std_logic := 'Z';
        RST : in std_logic
    );
end entity;

architecture tb of pasttrec_test_module is
    signal bitcounter   : integer range 0 to 18;
    signal datavector   : std_logic_vector(18 downto 0);

    signal rstcounter   : integer range 0 to 7;

    type ram_t is array(0 to 15) of std_logic_vector(7 downto 0);
    signal ram : ram_t;
begin
    SPI: process
        variable isok : std_logic;
        variable dataw : std_logic_vector(7 downto 0);
        variable addrw : std_logic_vector(3 downto 0);
    begin
        wait until rising_edge(SCK);
        isok := '1';
        SDI <= 'Z';

        if RST = '0' then
            isok := '0';
            rstcounter <= 7;
        end if;

        if rstcounter /= 0 and RST = '1' then
            rstcounter <= rstcounter - 1;
            isok := '0';
        end if;

        if rstcounter = 1 then
            --ram <= (
                            --0 => x"10",
                            --1 => x"00",
                            --2 => x"00",
                            --3 => x"08",
                            --4 => x"0F",
                            --5 => x"0F",
                            --6 => x"0F",
                            --7 => x"0F",
                            --8 => x"0F",
                            --9 => x"0F",
                            --10 => x"0F",
                            --11 => x"0F",
                            --12 => x"00",
                            --13 => x"05",
                            --others => x"00"
                            --);
            ram <= (
                            others => x"00"
                            );
        end if;

        datavector(18 downto 1) <= datavector (17 downto 0);
        datavector(0) <= SDO;

        for i in 10 to 17 loop
            if datavector(i downto i-5) = "1010" & chipid then
                SDI <= SDO;
            end if;
        end loop;

        --if bitcounter = 0 and SDO /= '1' then
            --isok := '0';
        --end if;
        --if bitcounter = 1 and SDO /= '0' then
            --isok := '0';
        --end if;
        --if bitcounter = 2 and SDO /= '1' then
            --isok := '0';
        --end if;
        --if bitcounter = 3 and SDO /= '0' then
            --isok := '0';
        --end if;
        --if bitcounter = 4 and SDO /= chipid(1) then
            --isok := '0';
        --end if;
        --if bitcounter = 5 and SDO /= chipid(0) then
            --isok := '0';
        --end if;

        --if isok = '1' and bitcounter /= 18 then
            --bitcounter <= bitcounter + 1;
        --else
            --bitcounter <= 0;
        --end if;

        --if bitcounter >= 11 and bitcounter <= 18 and isok = '1' then
            --SDI <= SDO;
        --else
            --SDI <= 'Z';
        --end if;

        if datavector(17 downto 12) = "1010" & chipid then
            dataw := datavector(6 downto 0) & SDO;
            addrw := datavector(10 downto 7);
            ram(to_integer(unsigned(addrw))) <= dataw;
        end if;
    end process;
end architecture;
