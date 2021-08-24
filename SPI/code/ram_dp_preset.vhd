LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_ARITH.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;

use std.textio.all;

library work;
use work.trb_net_std.all;

entity ram_dp_preset is
  generic(
    depth : integer := 2;
    width : integer := 4;
    initfile : string := ""
    );
  port(
    CLK   : in  std_logic;
    wr1   : in  std_logic;
    a1    : in  std_logic_vector(depth-1 downto 0);
    dout1 : out std_logic_vector(width-1 downto 0);
    din1  : in  std_logic_vector(width-1 downto 0);
    a2    : in  std_logic_vector(depth-1 downto 0);
    dout2 : out std_logic_vector(width-1 downto 0);
    a3    : in  std_logic_vector(depth-1 downto 0);
    dout3 : out std_logic_vector(width-1 downto 0)
    );
end entity;

architecture ram_dp_arch of ram_dp_preset is
    type ram_t is array(0 to 2**depth-1) of std_logic_vector(width-1 downto 0);

    impure function read_from_file(filename : string) return ram_t is
        file text_file      : text open read_mode is filename;
        variable text_line  : line;
        variable mem        : ram_t;
    begin
        for i in 0 to 2**depth-1 loop
            readline(text_file, text_line);
            hread(text_line, mem(i));
        end loop;
        return mem;
    end function;

    SIGNAL ram : ram_t := read_from_file(initfile);
--  signal ram : std_logic_vector(2**depth*width-1 downto 0)  := content;
begin


  process(CLK)
    begin
      if rising_edge(CLK) then
        if a1 /= x"00" then
            if wr1 = '1' then
                ram(conv_integer(a1))   <= din1;
                dout1                   <= din1;
            else
                dout1 <= ram(conv_integer(a1));
            end if;
        else
            dout1 <= x"00000000";
        end if;

        if a2 /= x"00" then
            dout2 <= ram(conv_integer(a2));
        else
            dout2 <= x"00000000";
        end if;
        if a3 /= x"00" then
            dout3 <= ram(conv_integer(a3));
        else
            dout3 <= x"00000000";
        end if;
      end if;
    end process;

end architecture;
