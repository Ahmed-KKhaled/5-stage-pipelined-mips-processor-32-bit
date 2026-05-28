-- =============================================================
--  memories.vhd  (instruction memory + data memory)
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mips_pkg.all;

-- -------------------------------------------------------------------
--  INSTRUCTION MEMORY
--
--  Test program (word index -> instruction):
--
--  --- R-type ---
--   0  addi $1,$0,10          $1=10
--   1  addi $2,$0,3           $2=3
--   2  add  $3,$1,$2          $3=13
--   3  sub  $4,$1,$2          $4=7
--   4  and  $5,$1,$2          $5=2
--   5  or   $6,$1,$2          $6=11
--   6  xor  $7,$1,$2          $7=9
--   7  nor  $8,$1,$2          $8=~11
--   8  slt  $9,$2,$1          $9=1  (3<10)
--   9  sll  $10,$2,2          $10=12
--  10  srl  $11,$1,1          $11=5
--  11  sra  $12,$1,1          $12=5
--
--  --- I-type ---
--  12  addi $13,$0,100        $13=100
--  13  andi $14,$13,0x0F      $14=4
--  14  ori  $15,$0,0xFF       $15=255
--  15  lui  $16,1             $16=0x00010000
--  16  slti $17,$13,200       $17=1
--
--  --- Load-use hazard (stall) ---
--  17  sw   $3,0($0)          mem[0]=13
--  18  lw   $18,0($0)         $18=13
--  19  add  $19,$18,$2        $19=16  <- RAW stall on $18
--
--  --- EX->EX forwarding ---
--  20  addi $20,$0,5          $20=5
--  21  addi $21,$20,3         $21=8   <- forward $20 EX->EX
--  22  add  $22,$21,$20       $22=13  <- forward $21 EX->EX, $20 MEM->EX
--
--  --- Store / Load ---
--  23  addi $23,$0,77         $23=77
--  24  sw   $23,4($0)         mem[1]=77
--  25  lw   $24,4($0)         $24=77
--
--  --- BEQ taken (skip instr 28) ---
--  26  addi $25,$0,7          $25=7
--  27  addi $26,$0,7          $26=7
--  28  beq  $25,$26,+1        taken -> PC = 30
--  29  addi $27,$0,99         SKIPPED
--  30  addi $27,$0,55         $27=55
--
--  --- BNE taken (skip 33,34) ---
--  31  addi $28,$0,1
--  32  addi $29,$0,2
--  33  bne  $28,$29,+2        taken (1/=2) -> PC = 36
--  34  addi $30,$0,11         SKIPPED
--  35  addi $30,$0,22         SKIPPED
--  36  addi $30,$0,33         $30=33
--
--  --- J (jump to 40, skip 38,39) ---
--  37  j    40
--  38  addi $1,$0,111         SKIPPED
--  39  addi $1,$0,222         SKIPPED
--  40  addi $1,$0,5           $1=5
--
--  --- JAL (jump to 43, $ra=PC+4 of instr41) ---
--  41  jal  43
--  42  addi $1,$0,999         SKIPPED
--  43  nop                    landed here
--
--  44+ nop
-- -------------------------------------------------------------------
entity instruction_memory is
    generic (MEM_SIZE : integer := 512);
    port (
        addr  : in  std_logic_vector(31 downto 0);
        instr : out std_logic_vector(31 downto 0)
    );
end entity instruction_memory;

architecture rtl of instruction_memory is
    type imem_t is array (0 to MEM_SIZE-1) of std_logic_vector(31 downto 0);

    constant IMEM : imem_t := (
	-- 0  addi $1, $0, 5      --> Load immediate value 5 into register $1 (Base Address)
	0  => x"20010005",
	
	-- 1  lw   $2, 0($1)      --> Load word from Memory address ($1 + 0) into register $2
	1  => x"8C220000",
	
	-- 2  add  $3, $2, $1     --> LOAD-USE HAZARD! Register $2 is needed before it is ready.
	2  => x"00411820",        -- Hazard Unit must freeze PC and inject a STALL (Bubble) here.
	
	-- 3  sub  $4, $3, $1     --> Normal R-type instruction dependent on $3 from the previous ADD
	3  => x"00612022",
	
	-- 4  nop                 --> No Operation to allow the pipeline to settle
	4  => x"00000000",
	
	others => x"00000000"
    );
begin
    instr <= IMEM(to_integer(unsigned(addr(31 downto 2))) mod MEM_SIZE);
end architecture rtl;


-- =============================================================
--  DATA MEMORY
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mips_pkg.all;

entity data_memory is
    generic (MEM_SIZE : integer := 256);
    port (
        clk     : in  std_logic;
        addr    : in  std_logic_vector(31 downto 0);
        wr_en   : in  std_logic;
        wr_data : in  std_logic_vector(31 downto 0);
        rd_en   : in  std_logic;
        rd_data : out std_logic_vector(31 downto 0)
    );
end entity data_memory;

architecture rtl of data_memory is
    type dmem_t is array (0 to MEM_SIZE-1) of std_logic_vector(31 downto 0);
    signal mem       : dmem_t := (others => (others => '0'));
    signal word_addr : integer;
begin
    word_addr <= to_integer(unsigned(addr(31 downto 2))) mod MEM_SIZE;

    process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' then
                mem(word_addr) <= wr_data;
            end if;
        end if;
    end process;

    rd_data <= mem(word_addr) when rd_en = '1' else (others => '0');
end architecture rtl;
