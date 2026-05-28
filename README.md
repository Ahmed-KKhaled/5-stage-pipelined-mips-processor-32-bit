# 32-Bit Pipelined MIPS Processor in VHDL

> A fully functional 5-stage pipelined MIPS processor implemented in VHDL with hazard detection, data forwarding, and branch handling — simulated and verified on ModelSim.

---

## Team Members

| # | Name |
|---|------|
| 1 | Ahmed Khaled Mohamed Barakat |
| 2 | Ahmed Tarek Elmargeny |
| 3 | Ibrahim Sameh Salah |

---

## Pipeline Architecture


---<img width="1042" height="667" alt="WhatsApp Image 2026-05-28 at 14 54 39" src="https://github.com/user-attachments/assets/04f278ac-520f-4e71-9931-8508574bc724" />


## Features

- 5-stage pipeline: **IF → ID → EX → MEM → WB**
- Full **32-bit** datapath with **32 general-purpose registers**
- Complete **MIPS-I** instruction set support
- **Full data forwarding** — eliminates most RAW hazards with zero stalls
- **Load-use hazard detection** — 1-cycle stall insertion
- **Branch handling** — assume not-taken policy with flush on taken
- **Jump support** — J, JAL, JR

---

## Supported Instructions

| Type | Instructions |
|------|-------------|
| R-Type | ADD, SUB, AND, OR, XOR, NOR, SLT, SLTU, SLL, SRL, SRA, JR |
| I-Type | ADDI, ADDIU, ANDI, ORI, XORI, SLTI, SLTIU, LUI |
| Memory | LW, SW, LB, LBU |
| Branch | BEQ, BNE |
| Jump | J, JAL |

---

## Hazard Handling

### 1. RAW Data Hazard
- **Problem:** An instruction reads a register before a previous instruction writes it.
- **Solution:** Full forwarding from EX/MEM and MEM/WB pipeline registers directly to the ALU inputs — no stall needed.

### 2. Load-Use Hazard
- **Problem:** A `LW` instruction followed immediately by an instruction that uses the loaded register.
- **Solution:** The hazard detection unit stalls the pipeline for 1 cycle by freezing PC and IF/ID, and inserting a bubble into ID/EX.

### 3. Control Hazard (Branch / Jump)
- **Problem:** Branch target is unknown until the MEM stage.
- **Solution:** Assume branch not-taken. If the branch is taken, flush the 2 incorrectly fetched instructions. Jumps (J/JAL/JR) flush 1 instruction.

---

## Project Structure<img width="1042" height="667" alt="WhatsApp Image 2026-05-28 at 14 54 39" src="https://github.com/user-attachments/assets/12b72b04-e694-4c7c-9829-6cb4596af071" />

mips_pipeline/
├── mips_pkg.vhd          # Shared package: types, constants, control record
├── register_file.vhd     # 32x32 dual-read single-write register file
├── alu.vhd               # 32-bit ALU (ADD, SUB, AND, OR, SLT, SLL, ...)
├── control_unit.vhd      # Opcode decoder -> control signals
├── hazard_forward.vhd    # Hazard detection unit + forwarding unit
├── memories.vhd          # Instruction memory (ROM) + data memory (RAM)
├── mips_pipeline.vhd     # Top-level: all 5 stages wired together
└── mips_pipeline_tb.vhd  # Testbench: runs test program, 800ns simulation

---

## How to Run (ModelSim)

**1. Compile all files in order:**

```tcl
vcom -work work -2002 -explicit mips_pkg.vhd
vcom -work work -2002 -explicit register_file.vhd
vcom -work work -2002 -explicit alu.vhd
vcom -work work -2002 -explicit control_unit.vhd
vcom -work work -2002 -explicit hazard_forward.vhd
vcom -work work -2002 -explicit memories.vhd
vcom -work work -2002 -explicit mips_pipeline.vhd
vcom -work work -2002 -explicit mips_pipeline_tb.vhd
```

**2. Start simulation:**

```tcl
vsim work.mips_pipeline_tb
```

**3. Add signals and run:**

```tcl
add wave -r /*
run 800ns
```

---

## Key Signals to Monitor

| Signal | Description |
|--------|-------------|
| `pc` | Program counter — jumps on branch/jump |
| `stall` | Goes HIGH for 1 cycle on load-use hazard |
| `branch_taken` | Goes HIGH when BEQ/BNE condition is true |
| `forwardA / forwardB` | `00` = no forward, `01` = MEM/WB, `10` = EX/MEM |
| `wb_rd` | Destination register being written |
| `wb_data` | Value written to destination register |

---

## Test Program Results

| Test | Expected Result |
|------|----------------|
| R-Type (ADD, SUB, AND ...) | `$3=13`, `$4=7`, `$5=2`, `$6=11` |
| I-Type (ADDI, ORI, LUI ...) | `$13=100`, `$15=255`, `$16=0x00010000` |
| Load-Use Stall | `stall=1` for 1 cycle, `$18=13`, `$19=16` |
| EX Forwarding | `$20=5`, `$21=8`, `$22=13` — no stall |
| BEQ Taken | Instruction 29 skipped, `$27=55` |
| BNE Taken | Instructions 34,35 skipped, `$30=33` |
| J / JAL | `$1=5` after J, `$ra=PC+4` after JAL |

---

## Tools Used

- **Language:** VHDL (IEEE 1076-2002)
- **Simulation:** ModelSim Altera 10.1
- **Target Architecture:** MIPS-I 32-bit

---

## License

This project is open source and available under the [MIT License](LICENSE).
