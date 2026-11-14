# Direct-Mapped Cache Controller (Verilog HDL)

An IEEE-standard, synthesizable **4 KB Direct-Mapped Cache Controller** designed in Verilog HDL for 32-bit computing systems, featuring a **Write-Back** and **Write-Allocate** policy with dirty-bit tracking.

---

## 👥 Team Responsibilities & Division of Work

| Member | Primary Responsibility | Key Deliverables |
|---|---|---|
| **Member 1** *(Current)* | **Cache Architecture & Verilog Design** | RTL Modules (`cache_controller.v`, `cache_tag_array.v`, `cache_data_array.v`, `cache_defines.vh`), Architecture Specs |
| **Member 2** | **Testbench, Simulation & Verification** | Testbenches (`tb_cache_controller.v`), test vectors, hit/miss verification, waveform generation (VCD) |
| **Member 3** | **Memory Interface, Integration & Documentation** | Memory subsystem model (`main_memory.v`), top integration, IEEE report formatting & submission |

---

## 📐 System Specifications

- **Cache Organization:** Direct-Mapped (1-way associative)
- **Total Capacity:** 4 KB (256 lines × 16 bytes/line)
- **Line / Block Size:** 16 Bytes (128 bits = 4 words of 32 bits each)
- **Address Bus:** 32-bit byte-addressable
- **CPU Data Bus:** 32-bit word transactions
- **Memory Bus:** 128-bit block transactions
- **Write Policy:** Write-Back with Dirty-bit tracking
- **Allocation Policy:** Write-Allocate on write miss

### 32-Bit Memory Address Breakdown
```
+-----------------------------------+--------------------+------------------+------------------+
|            Tag [31:12]            |    Index [11:4]    | Word Offset [3:2]| Byte Offset [1:0]|
|              20 bits              |       8 bits       |      2 bits      |      2 bits      |
+-----------------------------------+--------------------+------------------+------------------+
```

---

## 📁 Repository Structure

```
MCA/
├── rtl/                        # Synthesizable Verilog RTL (Member 1)
│   ├── cache_defines.vh        # Global parameters & state definitions
│   ├── cache_tag_array.v       # 256-line Tag, Valid, and Dirty bit SRAM
│   ├── cache_data_array.v      # 4 KB Data SRAM with sub-word multiplexing
│   └── cache_controller.v      # Master FSM and Handshake Controller
├── docs/                       # Architecture & Report Documentation
│   ├── architecture_spec.md    # Detailed cache architecture and FSM specification
│   └── member1_contribution.md # IEEE Report section & Prototype video presentation notes
└── README.md                   # Project overview and instructions
```

---

## ⚙️ Finite State Machine (FSM)

The controller operates as a 5-state Mealy/Moore hybrid FSM:

1. **`S_IDLE` (`3'b000`):** Listens for incoming CPU requests (`cpu_req`).
2. **`S_COMPARE_TAG` (`3'b001`):** Compares address tag with stored tag.
   - Hit: Returns data immediately (read) or updates word and sets dirty (write).
   - Miss & Clean: Transitions to `S_ALLOCATE`.
   - Miss & Dirty: Transitions to `S_WRITE_BACK` to flush the old block.
3. **`S_WRITE_BACK` (`3'b010`):** Evicts dirty line to main memory.
4. **`S_ALLOCATE` (`3'b011`):** Fetches the missing 128-bit line from main memory.
5. **`S_UPDATE` (`3'b100`):** Updates the cache data/tag array and responds to the CPU.

---

## 🚀 Simulation & Verification (For Member 2 & 3)

The design is compatible with Icarus Verilog (`iverilog`), ModelSim, Synopsys VCS, and Vivado:

```bash
# Example compilation command using Icarus Verilog:
iverilog -I rtl -o sim_cache rtl/cache_defines.vh rtl/cache_tag_array.v rtl/cache_data_array.v rtl/cache_controller.v <testbench_file.v>
vvp sim_cache
gtkwave dump.vcd
```

