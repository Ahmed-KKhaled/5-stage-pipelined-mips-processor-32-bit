-- =============================================================
--  control_unit.vhd
--  Main control unit: decodes opcode ? generates ctrl_t signals
--  ALU control is also embedded here (no separate sub-unit needed
--  since we carry alu_op directly in ctrl_t).
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use work.mips_pkg.all;

entity control_unit is
    port (
        opcode   : in  std_logic_vector(5 downto 0);
        funct    : in  std_logic_vector(5 downto 0);  -- used for R-type ALU select
        ctrl_out : out ctrl_t
    );
end entity control_unit;

architecture rtl of control_unit is
    signal c : ctrl_t;
begin
    process(opcode, funct)
    begin
        -- safe defaults (NOP)
        c <= CTRL_NOP;

        case opcode is
            -- ---- R-type ----------------------------------------
            when OP_RTYPE =>
                c.reg_dst  <= '1';
                c.reg_write <= '1';
                -- decode funct ? alu_op
                case funct is
                    when FUNCT_ADD | FUNCT_ADDU => c.alu_op <= ALU_ADD;
                    when FUNCT_SUB              => c.alu_op <= ALU_SUB;
                    when FUNCT_AND              => c.alu_op <= ALU_AND;
                    when FUNCT_OR               => c.alu_op <= ALU_OR;
                    when FUNCT_XOR              => c.alu_op <= ALU_XOR;
                    when FUNCT_NOR              => c.alu_op <= ALU_NOR;
                    when FUNCT_SLT              => c.alu_op <= ALU_SLT;
                    when FUNCT_SLTU             => c.alu_op <= ALU_SLTU;
                    when FUNCT_SLL              => c.alu_op <= ALU_SLL;
                    when FUNCT_SRL              => c.alu_op <= ALU_SRL;
                    when FUNCT_SRA              => c.alu_op <= ALU_SRA;
                    when FUNCT_JR =>
                        c.jr        <= '1';
                        c.reg_write <= '0';
                    when others => null;
                end case;

            -- ---- I-type arithmetic -----------------------------
            when OP_ADDI | OP_ADDIU =>
                c.alu_src   <= '1';
                c.reg_write <= '1';
                c.alu_op    <= ALU_ADD;

            when OP_ANDI =>
                c.alu_src   <= '1';
                c.reg_write <= '1';
                c.alu_op    <= ALU_AND;

            when OP_ORI =>
                c.alu_src   <= '1';
                c.reg_write <= '1';
                c.alu_op    <= ALU_OR;

            when OP_XORI =>
                c.alu_src   <= '1';
                c.reg_write <= '1';
                c.alu_op    <= ALU_XOR;

            when OP_SLTI =>
                c.alu_src   <= '1';
                c.reg_write <= '1';
                c.alu_op    <= ALU_SLT;

            when OP_SLTIU =>
                c.alu_src   <= '1';
                c.reg_write <= '1';
                c.alu_op    <= ALU_SLTU;

            when OP_LUI =>
                c.alu_src   <= '1';
                c.reg_write <= '1';
                c.alu_op    <= ALU_LUI;

            -- ---- Load / Store ----------------------------------
            when OP_LW | OP_LB | OP_LBU =>
                c.alu_src    <= '1';
                c.mem_to_reg <= '1';
                c.reg_write  <= '1';
                c.mem_read   <= '1';
                c.alu_op     <= ALU_ADD;

            when OP_SW =>
                c.alu_src   <= '1';
                c.mem_write <= '1';
                c.alu_op    <= ALU_ADD;

            -- ---- Branch ----------------------------------------
            when OP_BEQ =>
                c.branch <= '1';
                c.alu_op <= ALU_SUB;   -- compare by subtraction

            when OP_BNE =>
                c.branch_ne <= '1';
                c.alu_op    <= ALU_SUB;

            -- ---- Jump ------------------------------------------
            when OP_J =>
                c.jump <= '1';

            when OP_JAL =>
                c.jump      <= '1';
                c.jal       <= '1';
                c.reg_write <= '1';   -- write $31

            when others => null;
        end case;
    end process;

    ctrl_out <= c;
end architecture rtl;
