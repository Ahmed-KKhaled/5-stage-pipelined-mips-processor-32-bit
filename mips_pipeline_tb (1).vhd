--  mips_pipeline_tb.vhd
--  Comprehensive testbench
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mips_pipeline_tb is
end entity mips_pipeline_tb;

architecture sim of mips_pipeline_tb is

    component mips_pipeline is
        port (clk : in std_logic; rst : in std_logic);
    end component;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    constant CLK_PERIOD : time := 10 ns;

begin

    U_DUT : mips_pipeline
        port map (clk => clk, rst => rst);

    clk <= not clk after CLK_PERIOD / 2;

    process
    begin
        rst <= '1';
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait for CLK_PERIOD * 80;
        assert false report "TB DONE" severity failure;
        wait;
    end process;

end architecture sim;
