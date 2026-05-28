--  hazard_unit.vhd
--  Load-use hazard detection: inserts a bubble (stall) when a
--  load instruction is immediately followed by an instruction
--  that reads the loaded register.
library ieee;
use ieee.std_logic_1164.all;
use work.mips_pkg.all;

entity hazard_unit is
    port (
        id_ex_mem_read : in  std_logic;
        id_ex_rt       : in  std_logic_vector(REG_ADDR-1 downto 0);
        if_id_rs       : in  std_logic_vector(REG_ADDR-1 downto 0);
        if_id_rt       : in  std_logic_vector(REG_ADDR-1 downto 0);
        stall          : out std_logic   -- '1' = freeze IF/ID + PC, flush ID/EX
    );
end entity hazard_unit;

architecture rtl of hazard_unit is
begin
    process(id_ex_mem_read, id_ex_rt, if_id_rs, if_id_rt)
    begin
        if (id_ex_mem_read = '1') and
           ((id_ex_rt = if_id_rs) or (id_ex_rt = if_id_rt)) and
           (id_ex_rt /= "00000") then
            stall <= '1';
        else
            stall <= '0';
        end if;
    end process;
end architecture rtl;



--  forwarding_unit.vhd
--  Detects EX and MEM forwarding opportunities and drives
--  the 2-bit MUX selects on the ALU inputs.
--
--  forwardA / forwardB encoding:
--    "00" = register file (no forward)
--    "01" = forward from MEM/WB  (1 cycle ago)
--    "10" = forward from EX/MEM  (this cycle)
library ieee;
use ieee.std_logic_1164.all;
use work.mips_pkg.all;

entity forwarding_unit is
    port (
        ex_mem_reg_write  : in  std_logic;
        ex_mem_rd         : in  std_logic_vector(REG_ADDR-1 downto 0);
        mem_wb_reg_write  : in  std_logic;
        mem_wb_rd         : in  std_logic_vector(REG_ADDR-1 downto 0);
        id_ex_rs          : in  std_logic_vector(REG_ADDR-1 downto 0);
        id_ex_rt          : in  std_logic_vector(REG_ADDR-1 downto 0);
        forwardA          : out std_logic_vector(1 downto 0);
        forwardB          : out std_logic_vector(1 downto 0)
    );
end entity forwarding_unit;

architecture rtl of forwarding_unit is
begin
    process(ex_mem_reg_write, ex_mem_rd,
            mem_wb_reg_write, mem_wb_rd,
            id_ex_rs, id_ex_rt)
    begin
        -- ---- forwardA (rs) ----
        if (ex_mem_reg_write = '1') and
           (ex_mem_rd /= "00000") and
           (ex_mem_rd = id_ex_rs) then
            forwardA <= "10";   -- EX forwarding (highest priority)
        elsif (mem_wb_reg_write = '1') and
              (mem_wb_rd /= "00000") and
              (mem_wb_rd = id_ex_rs) then
            forwardA <= "01";   -- MEM forwarding
        else
            forwardA <= "00";   -- no forward
        end if;

        -- ---- forwardB (rt) ----
        if (ex_mem_reg_write = '1') and
           (ex_mem_rd /= "00000") and
           (ex_mem_rd = id_ex_rt) then
            forwardB <= "10";
        elsif (mem_wb_reg_write = '1') and
              (mem_wb_rd /= "00000") and
              (mem_wb_rd = id_ex_rt) then
            forwardB <= "01";
        else
            forwardB <= "00";
        end if;
    end process;
end architecture rtl;
