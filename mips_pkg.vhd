--  mips_pkg.vhd
--  Shared types, constants, and helper functions
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mips_pkg is

    -- Basic word / address widths
    constant DATA_WIDTH : integer := 32;
    constant ADDR_WIDTH : integer := 32;
    constant REG_ADDR   : integer := 5;    -- 32 registers

    -- ALU operation codes
    constant ALU_ADD  : std_logic_vector(3 downto 0) := "0000";
    constant ALU_SUB  : std_logic_vector(3 downto 0) := "0001";
    constant ALU_AND  : std_logic_vector(3 downto 0) := "0010";
    constant ALU_OR   : std_logic_vector(3 downto 0) := "0011";
    constant ALU_XOR  : std_logic_vector(3 downto 0) := "0100";
    constant ALU_NOR  : std_logic_vector(3 downto 0) := "0101";
    constant ALU_SLT  : std_logic_vector(3 downto 0) := "0110";
    constant ALU_SLTU : std_logic_vector(3 downto 0) := "0111";
    constant ALU_SLL  : std_logic_vector(3 downto 0) := "1000";
    constant ALU_SRL  : std_logic_vector(3 downto 0) := "1001";
    constant ALU_SRA  : std_logic_vector(3 downto 0) := "1010";
    constant ALU_LUI  : std_logic_vector(3 downto 0) := "1011";

    -- MIPS R-type funct field
    constant FUNCT_ADD  : std_logic_vector(5 downto 0) := "100000";
    constant FUNCT_ADDU : std_logic_vector(5 downto 0) := "100001";
    constant FUNCT_SUB  : std_logic_vector(5 downto 0) := "100010";
    constant FUNCT_AND  : std_logic_vector(5 downto 0) := "100100";
    constant FUNCT_OR   : std_logic_vector(5 downto 0) := "100101";
    constant FUNCT_XOR  : std_logic_vector(5 downto 0) := "100110";
    constant FUNCT_NOR  : std_logic_vector(5 downto 0) := "100111";
    constant FUNCT_SLT  : std_logic_vector(5 downto 0) := "101010";
    constant FUNCT_SLTU : std_logic_vector(5 downto 0) := "101011";
    constant FUNCT_SLL  : std_logic_vector(5 downto 0) := "000000";
    constant FUNCT_SRL  : std_logic_vector(5 downto 0) := "000010";
    constant FUNCT_SRA  : std_logic_vector(5 downto 0) := "000011";
    constant FUNCT_JR   : std_logic_vector(5 downto 0) := "001000";

    -- MIPS opcode field
    constant OP_RTYPE : std_logic_vector(5 downto 0) := "000000";
    constant OP_ADDI  : std_logic_vector(5 downto 0) := "001000";
    constant OP_ADDIU : std_logic_vector(5 downto 0) := "001001";
    constant OP_ANDI  : std_logic_vector(5 downto 0) := "001100";
    constant OP_ORI   : std_logic_vector(5 downto 0) := "001101";
    constant OP_XORI  : std_logic_vector(5 downto 0) := "001110";
    constant OP_SLTI  : std_logic_vector(5 downto 0) := "001010";
    constant OP_SLTIU : std_logic_vector(5 downto 0) := "001011";
    constant OP_LUI   : std_logic_vector(5 downto 0) := "001111";
    constant OP_LW    : std_logic_vector(5 downto 0) := "100011";
    constant OP_SW    : std_logic_vector(5 downto 0) := "101011";
    constant OP_LB    : std_logic_vector(5 downto 0) := "100000";
    constant OP_LBU   : std_logic_vector(5 downto 0) := "100100";
    constant OP_BEQ   : std_logic_vector(5 downto 0) := "000100";
    constant OP_BNE   : std_logic_vector(5 downto 0) := "000101";
    constant OP_J     : std_logic_vector(5 downto 0) := "000010";
    constant OP_JAL   : std_logic_vector(5 downto 0) := "000011";

    -- Control signals record (passed through pipeline registers)
    type ctrl_t is record
        reg_dst    : std_logic;  -- '1' = rd, '0' = rt
        alu_src    : std_logic;  -- '1' = imm, '0' = reg
        mem_to_reg : std_logic;  -- '1' = from mem, '0' = from ALU
        reg_write  : std_logic;
        mem_read   : std_logic;
        mem_write  : std_logic;
        branch     : std_logic;
        branch_ne  : std_logic;
        jump       : std_logic;
        jal        : std_logic;
        jr         : std_logic;
        alu_op     : std_logic_vector(3 downto 0);
    end record;

    constant CTRL_NOP : ctrl_t := (
        reg_dst    => '0',
        alu_src    => '0',
        mem_to_reg => '0',
        reg_write  => '0',
        mem_read   => '0',
        mem_write  => '0',
        branch     => '0',
        branch_ne  => '0',
        jump       => '0',
        jal        => '0',
        jr         => '0',
        alu_op     => ALU_ADD
    );

end package mips_pkg;
