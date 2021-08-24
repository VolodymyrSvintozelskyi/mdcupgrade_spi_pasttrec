library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use IEEE.math_real.all;

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

    signal SPI_CS_OUT      : std_logic;
    signal SPI_SDI_IN      : std_logic;
    signal SPI_SDO_OUT     : std_logic;
    signal SPI_SCK_OUT     : std_logic;
    signal SPI_RST_OUT     : std_logic;

    constant TbPeriod : time := 5 ns; -- EDIT Put right period here
    signal TbSimEnded : std_logic := '0';

    type spi_hist_t is array(0 to 10000) of std_logic_vector(18 downto 0);
    signal spi_hist        : spi_hist_t;
    signal spi_hist_ind    : integer := 0;
    signal spi_catch_active: std_logic := '0';

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

    signal wait_for_responce : std_logic_vector(2 downto 0);
    signal wait_en           : std_logic := '0';
    signal wait_cnt          : integer :=0;
    signal wait_end          : std_logic := '0';
    signal wait_error        : std_logic := '0';
    constant max_wait_cnt    : integer := 5;
begin

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

    stimuli : process
        variable data           : std_logic_vector(18 downto 0);
        variable num_of_errors  : integer := 0;
        variable tmp            : std_logic_vector(31 downto 0);
        variable index          : integer := 0;
        variable start_autoload_ind : integer;
    begin
        -- EDIT Adapt initialization as needed
        BUS_RX.data     <= (others => '0');
        BUS_RX.addr     <= (others => '0');
        BUS_RX.write    <= '0';
        BUS_RX.read     <= '0';
        BUS_RX.timeout  <= '0';
        RST_IN          <= '1';
        SPI_SDI_IN      <= '1';

        wait for 4 * TbPeriod;
        wait until falling_edge(CLK);
        RST_IN          <= '0';


        wait until rising_edge(SPI_RST_OUT);
        wait until rising_edge(SPI_CS_OUT);
        wait for 150*TbPeriod;

        wait for 10 * TbPeriod;
        wait until falling_edge(CLK);

        echo ("MEMORY CHECK ---------------------------" & lf);
        for i in 0 to 16 loop
            wait until falling_edge(CLK);
            BUS_RX.read <= '1';
            BUS_RX.addr <= x"a0" & std_logic_vector(to_unsigned(i, 8));
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

            echo( "Memory addr=" & integer'image(i) & "  DATA: " & to_hstring(BUS_TX.data) & lf);
            assert BUS_TX.data = ram(i) report "MEMORY ERROR";
            if BUS_TX.data /= ram(i) then
                num_of_errors := num_of_errors + 1;
            end if;
        end loop;
        echo ("ERRORS: " & integer'image(num_of_errors) & "------------" & lf & lf & lf);

        wait for 5 * TbPeriod;

        echo ("SPI REGISTERS CHECK ---------------------------" & lf);

        for i in 0 to 2**15-1 loop
            wait until falling_edge(CLK);
            BUS_RX.write <= '1';
            BUS_RX.addr  <= x"a101";
            tmp(31 downto 8):= std_logic_vector(to_unsigned(i,24));
            tmp(7 downto 0) := "00000000";
            if to_integer(unsigned (tmp(19 downto 14))) > 19 then
                tmp(19 downto 14) := std_logic_vector(to_unsigned(19, 6));
            end if;
            BUS_RX.data  <= tmp;
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
            BUS_RX.read <= '1';
            BUS_RX.addr  <= x"a101";
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

            assert BUS_TX.data = tmp report "Incorrect data";
            if not (BUS_TX.data = tmp) then
                num_of_errors := num_of_errors+1;
            end if;

            wait until falling_edge(CLK);
            BUS_RX.read <= '1';
            BUS_RX.addr  <= x"a102";
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

            assert BUS_TX.data(5 downto 0) = tmp(13 downto 8) report "Incorrect data";
            if not (BUS_TX.data(5 downto 0) = tmp(13 downto 8)) then
                num_of_errors := num_of_errors+1;
            end if;

            wait until falling_edge(CLK);
            BUS_RX.read <= '1';
            BUS_RX.addr  <= x"a107";
            wait until falling_edge(CLK);
            BUS_RX.read <= '0';

            --------------- WAIT BLOCK------------------
            wait_for_responce <= "001";
            wait_en <= '1';
            wait until rising_edge(CLK) and wait_end = '1';
            if wait_error = '1' then
                num_of_errors := num_of_errors + 1;
            end if;
            wait_en <= '0';
            --------------- END WAIT BLOCK------------------

            wait until falling_edge(CLK);
            BUS_RX.read <= '1';
            BUS_RX.addr  <= x"a103";
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

            assert BUS_TX.data(15 downto 0) = tmp(29 downto 14) report "Incorrect data";
            if not (BUS_TX.data(15 downto 0) = tmp(29 downto 14)) then
                num_of_errors := num_of_errors+1;
            end if;

        end loop;
        echo ("ERRORS: " & integer'image(num_of_errors) & "------------" & lf & lf & lf);

        wait until falling_edge(CLK);
        report "SPI REGISTERS RESET ---------------------------" & lf;
        RST_IN <= '1';
        wait until falling_edge(CLK);
        RST_IN <= '0';

        wait until rising_edge(SPI_RST_OUT);
        wait until rising_edge(SPI_CS_OUT);
        wait for 150*TbPeriod;
        spi_catch_active <= '1';
        wait until falling_edge(CLK);

        echo ("PASTTREC REGISTERS WRITE CHECK ---------------------------" & lf);
        --wait;
        for chip_id in 0 to 3 loop
            for reg_no in 0 to 15 loop
                for data in 0 to 2*8 - 1 loop
                    wait until falling_edge(CLK);
                    BUS_RX.write <= '1';
                    BUS_RX.addr  <= x"a2" & "00" & std_logic_vector(to_unsigned(chip_id,2)) & std_logic_vector(to_unsigned(reg_no,4));
                    BUS_RX.data  <= std_logic_vector(to_unsigned(data ,32));
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
                    BUS_RX.addr  <= x"a2" & "00" & std_logic_vector(to_unsigned(chip_id,2)) & std_logic_vector(to_unsigned(15-reg_no,4));
                    BUS_RX.data  <= std_logic_vector(to_unsigned(2*8-1-data ,32));
                    wait until falling_edge(CLK);
                    BUS_RX.write <= '0';

                    --------------- WAIT BLOCK------------------
                    wait_for_responce <= "010";
                    wait_en <= '1';
                    wait until rising_edge(CLK) and wait_end = '1';
                    if wait_error = '1' then
                        num_of_errors := num_of_errors + 1;
                    end if;
                    wait_en <= '0';
                    --------------- END WAIT BLOCK------------------

                    wait for 10*TbPeriod;

                    wait until falling_edge(CLK);
                    BUS_RX.write <= '1';
                    BUS_RX.addr  <= x"a2" & "00" & std_logic_vector(to_unsigned(chip_id,2)) & std_logic_vector(to_unsigned(15-reg_no,4));
                    BUS_RX.data  <= std_logic_vector(to_unsigned(2*8-1-data ,32));
                    wait until falling_edge(CLK);
                    BUS_RX.write <= '0';

                    --------------- WAIT BLOCK------------------
                    wait_for_responce <= "010";
                    wait_en <= '1';
                    wait until rising_edge(CLK) and wait_end = '1';
                    if wait_error = '1' then
                        num_of_errors := num_of_errors + 1;
                    end if;
                    wait_en <= '0';
                    --------------- END WAIT BLOCK------------------

                    wait for 10*TbPeriod;

                    wait until falling_edge(CLK);
                    BUS_RX.write <= '1';
                    BUS_RX.addr  <= x"a7" & "00" & std_logic_vector(to_unsigned(chip_id,2)) & std_logic_vector(to_unsigned(15-reg_no,4));
                    wait until falling_edge(CLK);
                    BUS_RX.write <= '0';

                    --------------- WAIT BLOCK------------------
                    wait_for_responce <= "001";
                    wait_en <= '1';
                    wait until rising_edge(CLK) and wait_end = '1';
                    if wait_error = '1' then
                        num_of_errors := num_of_errors + 1;
                    end if;
                    wait_en <= '0';
                    --------------- END WAIT BLOCK------------------


                    wait until rising_edge(SPI_CS_OUT);
                    wait for 10*TbPeriod;
                end loop;
            end loop;
        end loop;

        wait for 100*TbPeriod;


        for chip_id in 0 to 3 loop
            for reg_no in 0 to 15 loop
                for data_reg in 0 to 2*8 - 1 loop
                    data := spi_hist(index);
                    index := index + 1;
                    assert data = "1010" & std_logic_vector(to_unsigned(chip_id,2)) & '0' & std_logic_vector(to_unsigned(reg_no,4)) & std_logic_vector(to_unsigned(data_reg, 8)) report "Incorrect SPI: data is " & to_string(data) & " but should be " & to_string("1010" & std_logic_vector(to_unsigned(chip_id,2)) & '0' & std_logic_vector(to_unsigned(reg_no,4)) & std_logic_vector(to_unsigned(data_reg, 8)));
                    if not (data = "1010" & std_logic_vector(to_unsigned(chip_id,2)) & '0' & std_logic_vector(to_unsigned(reg_no,4)) & std_logic_vector(to_unsigned(data_reg, 8))) then
                        num_of_errors := num_of_errors + 1;
                    end if;
                end loop;
            end loop;
        end loop;

        --echo( lf & lf & lf & "----------------------------" &lf&"SPI history:"&lf);
        --echo("             HEX | HEADER | ADDR | R/W | REG  | DATA" & lf );
        --for i in 0 to spi_hist_ind - 1 loop
            --data := spi_hist(i);
            --echo( "SPI CATCH: " & to_hstring(data) & " |  " & to_string(data(18 downto 15)) & "  |  " & to_string(data(14 downto 13)) & "  |  " & to_string(data(12)) & "  | " & to_string(data(11 downto 8)) & " | " & to_string(data(7 downto 0))  & lf);
        --end loop;

        echo (lf& "SC RESET" & lf);
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aA" & x"00";
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

        wait for 5*TbPeriod;
        assert SPI_RST_OUT  = '0' report "SC RESET failed!";
        if SPI_RST_OUT  /= '0' then
            num_of_errors := num_of_errors+1;
        end if;
        wait until rising_edge(SPI_RST_OUT);
        wait until rising_edge(SPI_CS_OUT);
        wait for 150*TbPeriod;
        assert spi_hist(spi_hist_ind - 1) = std_logic_vector(to_unsigned(0,19)) and spi_hist(spi_hist_ind - 2) = std_logic_vector(to_unsigned(0,19)) report "SC RESET Failed!";
        if not(spi_hist(spi_hist_ind - 1) = std_logic_vector(to_unsigned(0,19)) and spi_hist(spi_hist_ind - 2) = std_logic_vector(to_unsigned(0,19))) then
            num_of_errors := num_of_errors + 1;
        end if;

        wait for 100*TbPeriod;
        echo (lf& "SC AUTOLOAD SET" & lf);
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a0" & x"02";
        BUS_RX.data  <= "0100" & x"5" & x"10" & "0111" & x"F" & x"20";
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
        BUS_RX.addr  <= x"a0" & x"03";
        BUS_RX.data  <= "0100" & x"3" & x"10" & "0000" & x"0" & x"00";
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
        BUS_RX.addr  <= x"aA" & x"00";
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

        start_autoload_ind := spi_hist_ind;
        wait for 1000000*TbPeriod;

        if (spi_hist_ind - start_autoload_ind) /= 2+63+5+3 then
            report "Incorrect number of SPI commands! Actual is " & integer'image(spi_hist_ind-start_autoload_ind);
            num_of_errors := num_of_errors + 1;
        end if;

        for i in start_autoload_ind to spi_hist_ind - 1 loop
            if i - start_autoload_ind = 0 or i - start_autoload_ind = 1 then
                if spi_hist(i) /= std_logic_vector(to_unsigned(0,19)) then
                    report "Incorrect SPI! " & integer'image(i-start_autoload_ind);
                    num_of_errors := num_of_errors + 1;
                end if;
            elsif i-start_autoload_ind < 63 + 2 then
                if spi_hist(i) /= ram(32 + i - start_autoload_ind - 2)(18 downto 0) then
                    report "Incorrect SPI! " & integer'image(i-start_autoload_ind);
                    num_of_errors := num_of_errors + 1;
                end if;
            elsif i-start_autoload_ind < 5 + 63 + 2 then
                if spi_hist(i) /= ram(16 + i - start_autoload_ind - 2 - 63)(18 downto 0) then
                    report "Incorrect SPI! " & integer'image(i-start_autoload_ind);
                    num_of_errors := num_of_errors + 1;
                end if;
            elsif i-start_autoload_ind < 3 + 5 + 63 + 2 then
                if spi_hist(i) /= ram(16 + i - start_autoload_ind - 2 - 63 - 5)(18 downto 0) then
                    report "Incorrect SPI! " & integer'image(i-start_autoload_ind);
                    num_of_errors := num_of_errors + 1;
                end if;
            else
                report "Incorrect SPI! " & integer'image(i-start_autoload_ind);
                num_of_errors := num_of_errors + 1;
            end if;
        end loop;

        echo (lf & "-------------" & lf & "ERRORS: " & integer'image(num_of_errors) &lf & "-------------" & lf);

        echo ("Test load CMD" & lf);
        start_autoload_ind := spi_hist_ind;
        wait for 10*TbPeriod;
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aA" & x"41";
        BUS_RX.data  <= x"0000" & x"0A" & x"10";
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

        wait for 5000*TbPeriod;

        if (spi_hist_ind - start_autoload_ind) /= 10 then
            report "Incorrect number of SPI commands! Actual is " & integer'image(spi_hist_ind-start_autoload_ind);
            num_of_errors := num_of_errors + 1;
        end if;

        for i in start_autoload_ind to spi_hist_ind - 1 loop
            if i - start_autoload_ind  < 10 then
                if spi_hist(i)(12 downto 0) /= ram(16 + i - start_autoload_ind)(12 downto 0) or spi_hist(i)(18 downto 15) /= "1010" or spi_hist(i)(14 downto 13) /= "10" then
                    report "Incorrect SPI! " & integer'image(i-start_autoload_ind) & " Actual data is: " & to_hstring(spi_hist(i));
                    num_of_errors := num_of_errors + 1;
                end if;
            else
                report "Incorrect SPI! " & integer'image(i-start_autoload_ind) & " Actual data is: " & to_hstring(spi_hist(i));
                num_of_errors := num_of_errors + 1;
            end if;
        end loop;

        wait for 300*TbPeriod;

        start_autoload_ind := spi_hist_ind;
        wait for 10*TbPeriod;
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"aA" & x"81";
        BUS_RX.data  <= x"0000" & x"0B" & x"10";
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

        wait for 4*5000*TbPeriod;

        if (spi_hist_ind - start_autoload_ind) /= 4*11 then
            report "Incorrect number of SPI commands! Actual is " & integer'image(spi_hist_ind-start_autoload_ind);
            num_of_errors := num_of_errors + 1;
        end if;

        for i in start_autoload_ind to spi_hist_ind - 1 loop
            if i - start_autoload_ind  < 11 then
                if spi_hist(i)(12 downto 0) /= ram(16 + i - start_autoload_ind)(12 downto 0) or spi_hist(i)(18 downto 15) /= "1010" or spi_hist(i)(14 downto 13) /= "00" then
                    report "Incorrect SPI! " & integer'image(i-start_autoload_ind) & " Actual data is: " & to_hstring(spi_hist(i));
                    num_of_errors := num_of_errors + 1;
                end if;
            elsif i - start_autoload_ind  < 11 *2 then
                if spi_hist(i)(12 downto 0) /= ram(16 + i - start_autoload_ind - 11)(12 downto 0) or spi_hist(i)(18 downto 15) /= "1010" or spi_hist(i)(14 downto 13) /= "01" then
                    report "Incorrect SPI! " & integer'image(i-start_autoload_ind) & " Actual data is: " & to_hstring(spi_hist(i));
                    num_of_errors := num_of_errors + 1;
                end if;
            elsif i - start_autoload_ind  < 11 *3 then
                if spi_hist(i)(12 downto 0) /= ram(16 + i - start_autoload_ind - 2*11)(12 downto 0) or spi_hist(i)(18 downto 15) /= "1010" or spi_hist(i)(14 downto 13) /= "10" then
                    report "Incorrect SPI! " & integer'image(i-start_autoload_ind) & " Actual data is: " & to_hstring(spi_hist(i));
                    num_of_errors := num_of_errors + 1;
                end if;
            elsif i - start_autoload_ind  < 11 *4 then
                if spi_hist(i)(12 downto 0) /= ram(16 + i - start_autoload_ind - 3*11)(12 downto 0) or spi_hist(i)(18 downto 15) /= "1010" or spi_hist(i)(14 downto 13) /= "11" then
                    report "Incorrect SPI! " & integer'image(i-start_autoload_ind) & " Actual data is: " & to_hstring(spi_hist(i));
                    num_of_errors := num_of_errors + 1;
                end if;
            else
                report "Incorrect SPI! " & integer'image(i-start_autoload_ind) & " Actual data is: " & to_hstring(spi_hist(i));
                num_of_errors := num_of_errors + 1;
            end if;
        end loop;

        echo (lf & "-------------" & lf & "ERRORS: " & integer'image(num_of_errors) &lf & "-------------" & lf);

        wait for 5000*TbPeriod;
        echo ("SPI reset test during transmitting." & lf);
        spi_catch_active    <= '0';
        wait for 10*TbPeriod;
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a202";
        BUS_RX.data  <= x"000000" & x"AB";
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

        wait for 100*TbPeriod;
        wait until falling_edge(CLK);
        BUS_RX.write <= '1';
        BUS_RX.addr  <= x"a100";
        BUS_RX.data  <= x"F0000000";
        wait until falling_edge(CLK);
        BUS_RX.write <= '0';
        report "Send reset signal";
        --------------- WAIT BLOCK------------------
        wait_for_responce <= "100";
        wait_en <= '1';
        wait until rising_edge(CLK) and wait_end = '1';
        if wait_error = '1' then
            num_of_errors := num_of_errors + 1;
        end if;
        wait_en <= '0';
        --------------- END WAIT BLOCK------------------
        wait for 5*TbPeriod;
        if SPI_CS_OUT   /= '1' then
            report "Reset insuccesful!";
            num_of_errors := num_of_errors + 1;
        end if;

        echo (lf & "-------------" & lf & "ERRORS: " & integer'image(num_of_errors) &lf & "-------------" & lf);

        wait;
    end process;

    SPI_CATCH: process
        variable data : std_logic_vector (18 downto 0);
    begin
        wait until falling_edge(SPI_CS_OUT);
        if spi_catch_active='1' then
            loop
                for i in 18 downto 0 loop
                    wait until rising_edge(SPI_SCK_OUT);
                    data (i) := SPI_SDO_OUT;
                end loop;
                report "SPI CATCH: " & to_hstring(data) & " | " & to_string(data(18 downto 15)) & " | ADDR " & to_string(data(14 downto 13)) & " | R/W " & to_string(data(12)) & " | REG " & to_string(data(11 downto 8)) & " | DATA " & to_string(data(7 downto 0));
                spi_hist(spi_hist_ind) <= data;
                spi_hist_ind <= spi_hist_ind + 1;
                wait until rising_edge(SPI_CS_OUT) OR falling_edge(SPI_SCK_OUT);
                exit when SPI_CS_OUT = '1';
            end loop;
        end if;
    end process;

end tb;

-- Configuration block below is required by some simulators. Usually no need to edit.

configuration cfg_tb_loader of tb_loader is
    for tb
    end for;
end cfg_tb_loader;
