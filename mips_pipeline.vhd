--  mips_pipeline.vhd
--  Top-level 5-stage MIPS pipeline
--
--  Stages & pipeline registers:
--    IF  -> [IF/ID]  -> ID  -> [ID/EX]  -> EX
--        -> [EX/MEM] -> MEM -> [MEM/WB] -> WB
--
--  Hazard handling:
--    - Load-use: 1-cycle stall (hazard_unit)
--    - Data forwarding: EX?EX and MEM?EX (forwarding_unit)
--    - Control (branch/jump): assume branch-not-taken;
--      flush when taken (2-cycle penalty for branch, 0 for JAL/J)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mips_pkg.all;

entity mips_pipeline is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic   -- active-high synchronous reset
    );
end entity mips_pipeline;

architecture rtl of mips_pipeline is

    -- Component declarations
    component instruction_memory is
        generic (MEM_SIZE : integer := 512);
        port (addr  : in  std_logic_vector(31 downto 0);
              instr : out std_logic_vector(31 downto 0));
    end component;

    component data_memory is
        generic (MEM_SIZE : integer := 256);
        port (clk     : in  std_logic;
              addr    : in  std_logic_vector(31 downto 0);
              wr_en   : in  std_logic;
              wr_data : in  std_logic_vector(31 downto 0);
              rd_en   : in  std_logic;
              rd_data : out std_logic_vector(31 downto 0));
    end component;

    component register_file is
        port (clk     : in  std_logic;
              rs_addr : in  std_logic_vector(4 downto 0);
              rs_data : out std_logic_vector(31 downto 0);
              rt_addr : in  std_logic_vector(4 downto 0);
              rt_data : out std_logic_vector(31 downto 0);
              wr_en   : in  std_logic;
              wr_addr : in  std_logic_vector(4 downto 0);
              wr_data : in  std_logic_vector(31 downto 0));
    end component;

    component alu is
        port (a        : in  std_logic_vector(31 downto 0);
              b        : in  std_logic_vector(31 downto 0);
              shamt    : in  std_logic_vector(4  downto 0);
              alu_ctrl : in  std_logic_vector(3  downto 0);
              result   : out std_logic_vector(31 downto 0);
              zero     : out std_logic;
              overflow : out std_logic);
    end component;

    component control_unit is
        port (opcode   : in  std_logic_vector(5 downto 0);
              funct    : in  std_logic_vector(5 downto 0);
              ctrl_out : out ctrl_t);
    end component;

    component hazard_unit is
        port (id_ex_mem_read : in  std_logic;
              id_ex_rt       : in  std_logic_vector(4 downto 0);
              if_id_rs       : in  std_logic_vector(4 downto 0);
              if_id_rt       : in  std_logic_vector(4 downto 0);
              stall          : out std_logic);
    end component;

    component forwarding_unit is
        port (ex_mem_reg_write : in  std_logic;
              ex_mem_rd        : in  std_logic_vector(4 downto 0);
              mem_wb_reg_write : in  std_logic;
              mem_wb_rd        : in  std_logic_vector(4 downto 0);
              id_ex_rs         : in  std_logic_vector(4 downto 0);
              id_ex_rt         : in  std_logic_vector(4 downto 0);
              forwardA         : out std_logic_vector(1 downto 0);
              forwardB         : out std_logic_vector(1 downto 0));
    end component;

    -- IF stage signals
    signal pc          : std_logic_vector(31 downto 0) := (others => '0');
    signal pc_plus4    : std_logic_vector(31 downto 0);
    signal instr_fetch : std_logic_vector(31 downto 0);
    signal pc_next     : std_logic_vector(31 downto 0);

    -- IF/ID pipeline register
    signal ifid_pc4   : std_logic_vector(31 downto 0) := (others => '0');
    signal ifid_instr : std_logic_vector(31 downto 0) := (others => '0');

    -- ID stage signals
    signal id_opcode   : std_logic_vector(5  downto 0);
    signal id_rs       : std_logic_vector(4  downto 0);
    signal id_rt       : std_logic_vector(4  downto 0);
    signal id_rd       : std_logic_vector(4  downto 0);
    signal id_shamt    : std_logic_vector(4  downto 0);
    signal id_funct    : std_logic_vector(5  downto 0);
    signal id_imm16    : std_logic_vector(15 downto 0);
    signal id_jmp_tgt  : std_logic_vector(25 downto 0);
    signal id_rs_data  : std_logic_vector(31 downto 0);
    signal id_rt_data  : std_logic_vector(31 downto 0);
    signal id_imm_ext  : std_logic_vector(31 downto 0);  -- sign-extended
    signal id_imm_zext : std_logic_vector(31 downto 0);  -- zero-extended (ANDI/ORI)
    signal id_ctrl     : ctrl_t;
    signal id_branch_tgt : std_logic_vector(31 downto 0);

    -- ID/EX pipeline register
    signal idex_ctrl    : ctrl_t                          := CTRL_NOP;
    signal idex_pc4     : std_logic_vector(31 downto 0)  := (others => '0');
    signal idex_rs_data : std_logic_vector(31 downto 0)  := (others => '0');
    signal idex_rt_data : std_logic_vector(31 downto 0)  := (others => '0');
    signal idex_imm_ext : std_logic_vector(31 downto 0)  := (others => '0');
    signal idex_rs      : std_logic_vector(4  downto 0)  := (others => '0');
    signal idex_rt      : std_logic_vector(4  downto 0)  := (others => '0');
    signal idex_rd      : std_logic_vector(4  downto 0)  := (others => '0');
    signal idex_shamt   : std_logic_vector(4  downto 0)  := (others => '0');

    -- EX stage signals
    signal ex_alu_a    : std_logic_vector(31 downto 0);
    signal ex_alu_b_rt : std_logic_vector(31 downto 0);  -- after forward MUX
    signal ex_alu_b    : std_logic_vector(31 downto 0);  -- after src MUX (imm or rt)
    signal ex_alu_res  : std_logic_vector(31 downto 0);
    signal ex_alu_zero : std_logic;
    signal ex_alu_ovf  : std_logic;
    signal ex_rd_sel   : std_logic_vector(4  downto 0);  -- after reg_dst MUX
    signal forwardA    : std_logic_vector(1  downto 0);
    signal forwardB    : std_logic_vector(1  downto 0);

    -- EX/MEM pipeline register
    signal exmem_ctrl    : ctrl_t                         := CTRL_NOP;
    signal exmem_alu_res : std_logic_vector(31 downto 0) := (others => '0');
    signal exmem_rt_data : std_logic_vector(31 downto 0) := (others => '0');
    signal exmem_rd      : std_logic_vector(4  downto 0) := (others => '0');
    signal exmem_zero    : std_logic                      := '0';
    signal exmem_pc4     : std_logic_vector(31 downto 0) := (others => '0');

    -- Branch target (computed in EX, evaluated in MEM for simplicity)
    signal idex_branch_tgt : std_logic_vector(31 downto 0) := (others => '0');
    signal exmem_brnch_tgt : std_logic_vector(31 downto 0) := (others => '0');

    -- MEM stage signals
    signal mem_rd_data   : std_logic_vector(31 downto 0);
    signal branch_taken  : std_logic;

    -- MEM/WB pipeline register
    signal memwb_ctrl    : ctrl_t                         := CTRL_NOP;
    signal memwb_mem_data: std_logic_vector(31 downto 0) := (others => '0');
    signal memwb_alu_res : std_logic_vector(31 downto 0) := (others => '0');
    signal memwb_rd      : std_logic_vector(4  downto 0) := (others => '0');
    signal memwb_pc4     : std_logic_vector(31 downto 0) := (others => '0');

    -- WB stage signals
    signal wb_data      : std_logic_vector(31 downto 0);
    signal wb_rd        : std_logic_vector(4  downto 0);

    -- Hazard / stall signals
    signal stall         : std_logic;
    signal flush_id      : std_logic;   -- flush IF/ID on branch
    signal flush_ex      : std_logic;   -- flush ID/EX on stall/branch

    -- Jump target
    signal jump_tgt      : std_logic_vector(31 downto 0);

begin

    -- IF Stage
    pc_plus4 <= std_logic_vector(unsigned(pc) + 4);

    -- Jump target: {PC+4[31:28], instr[25:0], 2'b00}
    jump_tgt <= ifid_pc4(31 downto 28) &
                ifid_instr(25 downto 0) & "00";

    -- Branch taken in MEM stage (evaluate zero flag)
    branch_taken <= (exmem_ctrl.branch    and     exmem_zero) or
                    (exmem_ctrl.branch_ne and not exmem_zero);

    -- PC mux priority: JR > JAL/J > branch > sequential
    process(pc_plus4, jump_tgt, exmem_brnch_tgt,
            branch_taken, id_ctrl, id_rs_data,
            ifid_instr, idex_ctrl, exmem_ctrl, idex_rs_data)
    begin
        if idex_ctrl.jr = '1' then
            -- JR: jump to rs value (already in ID/EX stage)
            pc_next <= idex_rs_data;
        elsif id_ctrl.jump = '1' then
            pc_next <= jump_tgt;
        elsif branch_taken = '1' then
            pc_next <= exmem_brnch_tgt;
        else
            pc_next <= pc_plus4;
        end if;
    end process;

    -- PC register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pc <= (others => '0');
            elsif stall = '0' then
                pc <= pc_next;
            end if;
        end if;
    end process;

    -- Instruction memory (combinational read)
    U_IMEM : instruction_memory
        generic map (MEM_SIZE => 512)
        port map (addr => pc, instr => instr_fetch);

    -- Flush control
    flush_id <= '1' when (id_ctrl.jump = '1') or (idex_ctrl.jr = '1') else '0';
    flush_ex <= '1' when (stall = '1') or (branch_taken = '1') else '0';

    -- IF/ID Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or flush_id = '1' then
                ifid_pc4   <= (others => '0');
                ifid_instr <= (others => '0');
            elsif stall = '0' then
                ifid_pc4   <= pc_plus4;
                ifid_instr <= instr_fetch;
            end if;
        end if;
    end process;

    -- ID Stage
    id_opcode  <= ifid_instr(31 downto 26);
    id_rs      <= ifid_instr(25 downto 21);
    id_rt      <= ifid_instr(20 downto 16);
    id_rd      <= ifid_instr(15 downto 11);
    id_shamt   <= ifid_instr(10 downto  6);
    id_funct   <= ifid_instr( 5 downto  0);
    id_imm16   <= ifid_instr(15 downto  0);
    id_jmp_tgt <= ifid_instr(25 downto  0);

    -- Sign-extend immediate
    id_imm_ext  <= (31 downto 16 => id_imm16(15)) & id_imm16;
    -- Zero-extend immediate (for ANDI / ORI / XORI)
    id_imm_zext <= (31 downto 16 => '0') & id_imm16;

    -- Branch target = PC+4 + (sign_ext(imm) << 2)
    id_branch_tgt <= std_logic_vector(
        unsigned(ifid_pc4) +
        unsigned(id_imm_ext(29 downto 0) & "00"));

    U_CTRL : control_unit
        port map (opcode   => id_opcode,
                  funct    => id_funct,
                  ctrl_out => id_ctrl);

    U_RF : register_file
        port map (clk     => clk,
                  rs_addr => id_rs,
                  rs_data => id_rs_data,
                  rt_addr => id_rt,
                  rt_data => id_rt_data,
                  wr_en   => memwb_ctrl.reg_write,
                  wr_addr => wb_rd,
                  wr_data => wb_data);

    -- Hazard detection unit
    U_HAZ : hazard_unit
        port map (id_ex_mem_read => idex_ctrl.mem_read,
                  id_ex_rt       => idex_rt,
                  if_id_rs       => id_rs,
                  if_id_rt       => id_rt,
                  stall          => stall);

    -- ID/EX Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or flush_ex = '1' then
                idex_ctrl       <= CTRL_NOP;
                idex_pc4        <= (others => '0');
                idex_rs_data    <= (others => '0');
                idex_rt_data    <= (others => '0');
                idex_imm_ext    <= (others => '0');
                idex_rs         <= (others => '0');
                idex_rt         <= (others => '0');
                idex_rd         <= (others => '0');
                idex_shamt      <= (others => '0');
                idex_branch_tgt <= (others => '0');
            else
                idex_ctrl       <= id_ctrl;
                idex_pc4        <= ifid_pc4;
                idex_rs_data    <= id_rs_data;
                idex_rt_data    <= id_rt_data;
                -- ANDI/ORI/XORI use zero-extended immediate
                if id_ctrl.alu_op = ALU_AND or
                   id_ctrl.alu_op = ALU_OR  or
                   id_ctrl.alu_op = ALU_XOR then
                    idex_imm_ext <= id_imm_zext;
                else
                    idex_imm_ext <= id_imm_ext;
                end if;
                idex_rs         <= id_rs;
                idex_rt         <= id_rt;
                idex_rd         <= id_rd;
                idex_shamt      <= id_shamt;
                idex_branch_tgt <= id_branch_tgt;
            end if;
        end if;
    end process;

    -- EX Stage

    -- Forwarding unit
    U_FWD : forwarding_unit
        port map (ex_mem_reg_write => exmem_ctrl.reg_write,
                  ex_mem_rd        => exmem_rd,
                  mem_wb_reg_write => memwb_ctrl.reg_write,
                  mem_wb_rd        => memwb_rd,
                  id_ex_rs         => idex_rs,
                  id_ex_rt         => idex_rt,
                  forwardA         => forwardA,
                  forwardB         => forwardB);

    -- Forward MUX for ALU input A (rs)
    with forwardA select ex_alu_a <=
        idex_rs_data  when "00",
        wb_data       when "01",
        exmem_alu_res when "10",
        idex_rs_data  when others;

    -- Forward MUX for ALU input B (rt before imm select)
    with forwardB select ex_alu_b_rt <=
        idex_rt_data  when "00",
        wb_data       when "01",
        exmem_alu_res when "10",
        idex_rt_data  when others;

    -- ALU source MUX (immediate or register)
    ex_alu_b <= idex_imm_ext when idex_ctrl.alu_src = '1' else ex_alu_b_rt;

    -- ALU instance
    U_ALU : alu
        port map (a        => ex_alu_a,
                  b        => ex_alu_b,
                  shamt    => idex_shamt,
                  alu_ctrl => idex_ctrl.alu_op,
                  result   => ex_alu_res,
                  zero     => ex_alu_zero,
                  overflow => ex_alu_ovf);

    -- Write-back destination MUX (rd for R-type, rt for I-type, $31 for JAL)
    ex_rd_sel <= "11111"    when idex_ctrl.jal     = '1' else
                 idex_rd    when idex_ctrl.reg_dst  = '1' else
                 idex_rt;

    -- EX/MEM Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                exmem_ctrl     <= CTRL_NOP;
                exmem_alu_res  <= (others => '0');
                exmem_rt_data  <= (others => '0');
                exmem_rd       <= (others => '0');
                exmem_zero     <= '0';
                exmem_pc4      <= (others => '0');
                exmem_brnch_tgt<= (others => '0');
            else
                exmem_ctrl      <= idex_ctrl;
                exmem_alu_res   <= ex_alu_res;
                exmem_rt_data   <= ex_alu_b_rt;  -- forwarded rt for SW
                exmem_rd        <= ex_rd_sel;
                exmem_zero      <= ex_alu_zero;
                exmem_pc4       <= idex_pc4;
                exmem_brnch_tgt <= idex_branch_tgt;
            end if;
        end if;
    end process;

    -- MEM Stage
    U_DMEM : data_memory
        generic map (MEM_SIZE => 256)
        port map (clk     => clk,
                  addr    => exmem_alu_res,
                  wr_en   => exmem_ctrl.mem_write,
                  wr_data => exmem_rt_data,
                  rd_en   => exmem_ctrl.mem_read,
                  rd_data => mem_rd_data);

    -- MEM/WB Pipeline Register
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                memwb_ctrl     <= CTRL_NOP;
                memwb_mem_data <= (others => '0');
                memwb_alu_res  <= (others => '0');
                memwb_rd       <= (others => '0');
                memwb_pc4      <= (others => '0');
            else
                memwb_ctrl     <= exmem_ctrl;
                memwb_mem_data <= mem_rd_data;
                memwb_alu_res  <= exmem_alu_res;
                memwb_rd       <= exmem_rd;
                memwb_pc4      <= exmem_pc4;
            end if;
        end if;
    end process;

    -- WB Stage
    -- Write-back data MUX: memory, ALU result, or PC+4 (JAL)
    wb_data <= memwb_pc4      when memwb_ctrl.jal       = '1' else
               memwb_mem_data when memwb_ctrl.mem_to_reg = '1' else
               memwb_alu_res;

    wb_rd <= memwb_rd;

end architecture rtl;
