--  alu.vhd
--  32-bit ALU for MIPS pipeline
--  Operations: ADD, SUB, AND, OR, XOR, NOR, SLT, SLTU,
--              SLL, SRL, SRA, LUI
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mips_pkg.all;

entity alu is
    port (
        a        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        b        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        shamt    : in  std_logic_vector(4 downto 0);   -- shift amount from instr[10:6]
        alu_ctrl : in  std_logic_vector(3 downto 0);
        result   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        zero     : out std_logic;
        overflow : out std_logic
    );
end entity alu;

architecture rtl of alu is
    signal res_int : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal add_ext : std_logic_vector(DATA_WIDTH downto 0);  -- extra bit for overflow
    signal sub_ext : std_logic_vector(DATA_WIDTH downto 0);
begin

    add_ext <= std_logic_vector(
                   signed('0' & a) + signed('0' & b));
    sub_ext <= std_logic_vector(
                   signed('0' & a) - signed('0' & b));

    process(a, b, shamt, alu_ctrl, add_ext, sub_ext)
    begin
        overflow <= '0';
        case alu_ctrl is
            when ALU_ADD =>
                res_int  <= add_ext(DATA_WIDTH-1 downto 0);
                -- signed overflow: different signs of inputs, same sign as result
                overflow <= (a(DATA_WIDTH-1) xnor b(DATA_WIDTH-1)) and
                            (a(DATA_WIDTH-1) xor  add_ext(DATA_WIDTH-1));

            when ALU_SUB =>
                res_int  <= sub_ext(DATA_WIDTH-1 downto 0);
                overflow <= (a(DATA_WIDTH-1) xor  b(DATA_WIDTH-1)) and
                            (a(DATA_WIDTH-1) xor  sub_ext(DATA_WIDTH-1));

            when ALU_AND =>
                res_int <= a and b;

            when ALU_OR =>
                res_int <= a or b;

            when ALU_XOR =>
                res_int <= a xor b;

            when ALU_NOR =>
                res_int <= a nor b;

            when ALU_SLT =>
                -- Signed less-than
                if signed(a) < signed(b) then
                    res_int <= (0 => '1', others => '0');
                else
                    res_int <= (others => '0');
                end if;

            when ALU_SLTU =>
                -- Unsigned less-than
                if unsigned(a) < unsigned(b) then
                    res_int <= (0 => '1', others => '0');
                else
                    res_int <= (others => '0');
                end if;

            when ALU_SLL =>
                res_int <= std_logic_vector(
                               shift_left(unsigned(b), to_integer(unsigned(shamt))));

            when ALU_SRL =>
                res_int <= std_logic_vector(
                               shift_right(unsigned(b), to_integer(unsigned(shamt))));

            when ALU_SRA =>
                res_int <= std_logic_vector(
                               shift_right(signed(b), to_integer(unsigned(shamt))));

            when ALU_LUI =>
                -- Load upper immediate: b[15:0] -> result[31:16], zeros in [15:0]
                res_int <= b(15 downto 0) & x"0000";

            when others =>
                res_int <= (others => '0');
        end case;
    end process;

    result <= res_int;
    zero   <= '1' when res_int = x"00000000" else '0';

end architecture rtl;
