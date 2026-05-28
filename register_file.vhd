--  register_file.vhd
--  32 x 32-bit dual-read, single-write register file
--  Write is synchronous (rising edge); reads are combinational.
--  Register $0 is hardwired to zero.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mips_pkg.all;

entity register_file is
    port (
        clk      : in  std_logic;
        -- Read port A
        rs_addr  : in  std_logic_vector(REG_ADDR-1 downto 0);
        rs_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        -- Read port B
        rt_addr  : in  std_logic_vector(REG_ADDR-1 downto 0);
        rt_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        -- Write port
        wr_en    : in  std_logic;
        wr_addr  : in  std_logic_vector(REG_ADDR-1 downto 0);
        wr_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity register_file;

architecture rtl of register_file is
    type reg_array_t is array (0 to 31) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal regs : reg_array_t := (others => (others => '0'));
begin

    -- Synchronous write (register $0 write is silently ignored)
    process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' and wr_addr /= "00000" then
                regs(to_integer(unsigned(wr_addr))) <= wr_data;
            end if;
        end if;
    end process;

    -- Asynchronous read (forward written value for same-cycle read)
    rs_data <= (others => '0') when rs_addr = "00000" else
               wr_data         when (wr_en = '1' and wr_addr = rs_addr) else
               regs(to_integer(unsigned(rs_addr)));

    rt_data <= (others => '0') when rt_addr = "00000" else
               wr_data         when (wr_en = '1' and wr_addr = rt_addr) else
               regs(to_integer(unsigned(rt_addr)));

end architecture rtl;
