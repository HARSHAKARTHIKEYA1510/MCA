# 5-Minute Prototype Demonstration Video Script & Recording Guide

**Project Title:** Design and Implementation of a Direct-Mapped Cache Controller Using Verilog HDL  
**Target Video Duration:** Maximum 5 Minutes (0:00 – 5:00)  
**Registered Team Size:** 3 Members  

> [!IMPORTANT]
> **Faculty Clarification Note:**
> The academic rubric suggests a 5-member team template, but our registered group consists of **three (3)** active members. This video presentation is partitioned strictly among the 3 actual members without inventing non-existent contributors.

---

## 📹 Video Placeholder Link

```markdown
[Final Recorded Prototype Video Link: PENDING USER RECORDING - INSERT LINK HERE]
```
*(Note: As per engineering ethics guidelines, no fabricated video URL is provided. Use this script to record the demonstration on macOS and paste the published link above).*

---

## ⏱️ Video Timeline & Speaker Breakdown

```
+---------------------------------------------------------------------------------------+
| 0:00 - 0:30  | Phase 1: Team & Project Introduction (All 3 Members)                  |
| 0:30 - 1:15  | Phase 2: Cache Theory & Direct-Mapping Principles (Member 1)           |
| 1:15 - 2:00  | Phase 3: Hardware Architecture & Address Decomposition (Member 1)      |
| 2:00 - 3:30  | Phase 4: Verilog RTL Walkthrough & Live Simulation (Member 2)          |
| 3:30 - 4:30  | Phase 5: Hit/Miss Waveform Evidence & Conflict Analysis (Member 2)     |
| 4:30 - 5:00  | Phase 6: Verification Summary & Phase II Roadmap (Member 3)            |
+---------------------------------------------------------------------------------------+
```

---

## 🎙️ Verbatim Narration Script

### Phase 1: Introduction (0:00 – 0:30)
**[Visual: Title Slide showing Project Name, GitHub Repository, and 3 Member Names]**

- **Member 1 (`[Student 1 Name]`):**  
  *"Hello respected faculty and evaluators. Welcome to our Phase I project demonstration on the **Design and Implementation of a Synthesizable Direct-Mapped Cache Controller Using Verilog HDL**.  
  I am `[Student 1 Name]`, leading Cache Architecture and RTL design."*

- **Member 2 (`[Student 2 Name]`):**  
  *"I am `[Student 2 Name]`, responsible for Hardware Verification, Testbench Development, and Simulation Analysis."*

- **Member 3 (Akshay Yelakanti):**  
  *"And I am Akshay Yelakanti, handling Main Memory Subsystem Integration, Bus Handshake Protocols, and Academic Reporting.  
  Please note: while departmental guidelines mention a 5-member template, our registered project group strictly comprises the three of us."*

---

### Phase 2: Cache Theory & Direct-Mapping Principles (0:30 – 1:15)
**[Visual: Switch to Diagram of Memory Hierarchy and Processor-Memory Wall]**

- **Member 1 (`[Student 1 Name]`):**  
  *"In modern computing systems, CPU execution speed far outpaces DRAM access latency, creating the notorious 'memory wall'. To prevent constant processor stalling, we insert a small, ultra-fast cache memory.  
  For our design, we selected a **Direct-Mapped Cache**. In a direct-mapped architecture, each physical memory block maps to exactly one predetermined line in the cache. This eliminates the need for expensive multi-way comparators and LRU replacement circuitry, delivering the lowest silicon area and single-cycle access speeds."*

---

### Phase 3: Architecture & Address Decomposition (1:15 – 2:00)
**[Visual: Display `docs/Block_Diagrams/address_decomposition.svg`]**

- **Member 1 (`[Student 1 Name]`):**  
  *"Let's examine our 16-bit address decomposition. Every 16-bit memory address is partitioned into three fields:*
  - *Bits [1:0] (2 bits): **Byte Offset**, selecting 1 of 4 bytes within the cache line.*
  - *Bits [3:2] (2 bits): **Line Index**, directly addressing one of our 4 physical cache lines.*
  - *Bits [15:4] (12 bits): **Tag Field**, stored in SRAM to validate address ownership.*
  
  *Our cache has 4 lines of 4 bytes each, totaling 16 bytes.  
  Crucially, we implemented a **Write-Through** policy with **Write-Allocate**. On every write, both cache and main memory are updated simultaneously, keeping memory 100% coherent and eliminating the complexity of dirty bits.  
  Now, Member 2 will demonstrate our Verilog RTL and simulation."*

---

### Phase 4: Verilog RTL & Live Simulation (2:00 – 3:30)
**[Visual: VS Code showing `rtl/` directory, then Terminal window executing simulation]**

- **Member 2 (`[Student 2 Name]`):**  
  *"Thank you, `[Student 1 Name]`. Our synthesizable Verilog implementation consists of four modular entities:*
  1. *`cache_memory.v`: Stores 4 lines of 4 bytes, 12-bit tags, and valid flags.*
  2. *`cache_controller.v`: Houses our 6-state FSM: IDLE, LOOKUP, READ_MISS, ALLOCATE, WRITE_THROUGH, and COMPLETE.*
  3. *`direct_mapped_cache.v`: Integrates the controller and memory array.*
  4. *`main_memory.v`: Models secondary memory with 2-cycle latency.*

  *Now, let's run our comprehensive automated testbench live in terminal:"*

**[Action: Member 2 runs command in terminal]**
```bash
python3 scripts/simulate_cache.py
# (Or: ./scripts/run_sim.sh if Icarus Verilog is installed)
```

**[Visual: Terminal scrolls showing 20 automated assertions passing with `[PASS]` tags]**

- **Member 2 (`[Student 2 Name]`):**  
  *"As you can see on the screen, our testbench executed 20 automated assertions across 12 distinct verification scenarios. All 20 tests PASSED with a 100% success rate!"*

---

### Phase 5: Hit/Miss Analysis & Waveform Evidence (3:30 – 4:30)
**[Visual: Show GTKWave or waveform viewer displaying `simulation/waveforms/cache_sim.vcd`]**

- **Member 2 (`[Student 2 Name]`):**  
  *"Let's highlight the most critical test cases:*
  1. * **Initial Cold Miss on `0x0034`:** The cache starts empty (`valid = 0`). The controller stalls, fetches the 4-byte block (`0xA0` to `0xA3`) from memory, stores it in Line 1, and returns `0xA0` with `cpu_hit = 0`.*
  2. * **Spatial Locality Hit on `0x0035`:** Accessing the next consecutive byte immediately produces `cpu_hit = 1` in single-cycle turnaround because the block was already brought into Line 1.*
  3. * **Write Hit & Memory Coherence on `0x0035`:** Writing `0x55` modifies Line 1 Offset 1 and writes through to main memory, maintaining complete coherence.*
  4. * **Conflict Miss & Replacement (`0x0034` vs `0x0044`):** Address `0x0044` has Tag `0x004` but shares Index `2'b01` with `0x0034`. When accessed, the controller detects a tag mismatch, replaces Line 1 with block `0x0044`, and evicts `0x0034`.*
  *Notice on the waveform how `fsm_state`, `cpu_ready`, and `cpu_hit` toggle with zero timing violations."*

---

### Phase 6: Memory Interface, Integration & Phase II Roadmap (4:15 – 5:00)
**[Visual: Display `docs/Block_Diagrams/memory_interface_timing.svg` and `system_architecture.svg`]**

- **Member 3 (Akshay Yelakanti):**  
  *"As the Integration and Memory Subsystem lead, I modeled our 64 KB secondary memory (`main_memory.v`) with a parameterized 2-cycle access latency to accurately simulate off-chip DRAM wait states.  
  Notice our timing handshake: on a miss, memory receives the block-aligned address `{mem_addr[15:2], 2'b00}`, counts two latency cycles, and pulses `mem_ready` while returning four packed bytes `{B3, B2, B1, B0}` on a 32-bit bus. On writes, memory commits the byte concurrently with the cache, ensuring 100% memory coherence.  
  In `direct_mapped_cache.v`, I structurally unified the FSM controller, the 4-line SRAM, and the memory bus into a single synthesizable entity. Our standalone memory suite verified 23 assertions with 100% pass coverage.  
  In Phase II, we will extend this interface to a 2-way set-associative cache with Write-Back dirty evictions. All RTL, waveforms, and our IEEE paper are live on GitHub. Thank you!"*

---

## 📋 Screen Recording Pre-Flight Checklist

Before pressing record, ensure:
- [ ] Screen resolution set to 1080p (1920x1080) for clear text readability.
- [ ] Terminal font size enlarged (`Command + +` in macOS Terminal or iTerm2).
- [ ] VS Code open with `direct_mapped_cache.v` and `cache_controller.v` side-by-side.
- [ ] Terminal open at project directory `/Users/.../MCA/MCA`.
- [ ] Browser or image viewer open with `docs/Block_Diagrams/system_architecture.svg` and `address_decomposition.svg`.
- [ ] GTKWave open (or screenshot ready) showing `simulation/waveforms/cache_sim.vcd`.
- [ ] Microphone audio levels tested to ensure clear, crisp voice recording without background noise.
