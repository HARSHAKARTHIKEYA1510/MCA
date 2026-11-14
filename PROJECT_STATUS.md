# Project Status: Direct-Mapped Cache Controller Using Verilog HDL

**Date:** November 14, 2026  
**Project Domain:** Computer Architecture and Digital Logic Design  
**Target Environment:** macOS (Darwin arm64)  
**Submission Deadline:** November 16, 2026, 11:59 PM IST  

---

## 1. Team Composition & Administrative Note

> [!IMPORTANT]
> **Faculty Clarification Flag:**
> The college project guidelines mention a default group size of **five (5)** members. However, our registered group strictly comprises **three (3)** members:
> - **Member 1 (Placeholder: `[Student 1 Name / Roll No]`):** Lead Cache Architecture & RTL Design
> - **Member 2 (Placeholder: `[Student 2 Name / Roll No]`):** Hardware Verification, Testbench & Simulation
> - **Member 3 (Placeholder: `[Student 3 Name / Roll No]`):** Memory Subsystem Integration, Documentation & IEEE Report
>
> We have **not** fabricated or invented two non-existent team members or artificial contributions. This document explicitly flags this discrepancy for academic and faculty review.

---

## 2. Workspace & File Inspection

### 2.1 Existing Files Discovered
Prior to execution, the repository (`MCA/` at `https://github.com/HARSHAKARTHIKEYA1510/MCA.git`) contained:
- `README.md`: Overview describing a preliminary 32-bit Write-Back cache model.
- `docs/architecture_spec.md`: Initial architectural specification for a 32-bit 4 KB cache.
- `docs/member1_contribution.md`: Draft notes for Member 1.
- `rtl/cache_defines.vh`: Macro definitions for 32-bit address / 128-bit line cache.
- `rtl/cache_tag_array.v`: 256-line Tag/Valid/Dirty SRAM model.
- `rtl/cache_data_array.v`: 4 KB Data SRAM model with sub-word multiplexing.
- `rtl/cache_controller.v`: 5-state FSM implementation for 32-bit Write-Back cache.

### 2.2 Preservation of Existing Valid Work
All preliminary 32-bit Write-Back RTL files have been safeguarded and archived in `rtl/archive_32bit_writeback/`. They remain fully available as reference material and an architectural baseline for Phase II extension.

### 2.3 Identified Problems & Discrepancies
1. **Architectural Specification Mismatch:**
   - The initial files in `rtl/` implemented a **32-bit address, 4 KB data, Write-Back with Dirty-bit** cache.
   - The official college Phase I specification explicitly mandates:
     - **16-bit physical address** (`[15:0]`)
     - **8-bit data width** (byte-level access)
     - **4 cache lines** (2-bit index)
     - **4 bytes per line** (2-bit block offset)
     - **16 bytes total data capacity**
     - **12-bit tag field**
     - **Write-Through policy**
     - **Write-Allocate policy**
2. **Missing Essential Modules:**
   - `rtl/direct_mapped_cache.v`: Top-level integration module was missing.
   - `rtl/cache_memory.v`: Dedicated 4-line, 4-byte/line cache memory was missing.
   - `rtl/main_memory.v`: Behavioral byte-addressable main memory with block transfers and latency emulation was missing.
   - `testbench/cache_tb.v`: Comprehensive, self-checking Verilog testbench was missing.
3. **Missing Deliverables:**
   - Waveform dump files (`.vcd`) and simulation logs.
   - Formal IEEE Phase I conference report (`main.tex`, `references.bib`, `IEEE_report.pdf`).
   - Architectural flowcharts, block diagrams, and FSM transition state diagrams.
   - 5-minute prototype video presentation script and slide deck.
   - 30-question technical viva/interview preparation guide.

---

## 3. Toolchain & Environment Audit (macOS)

An environment audit was performed on the host macOS system:

| Tool | Status | Binary Location / Version | Notes / Remediation |
|---|---|---|---|
| **Homebrew** | Installed | `/opt/homebrew/bin/brew` (v7.0.10) | Active package manager |
| **Git** | Installed | `/opt/homebrew/bin/git` (v2.47.0) | Repository initialized and tracked |
| **Python 3** | Installed | `/opt/homebrew/bin/python3` (v3.14.7) | Available for cycle-accurate verification |
| **Icarus Verilog (`iverilog`)** | Missing | Not found in PATH | Required for native Verilog compilation |
| **VVP (`vvp`)** | Missing | Not found in PATH | Verilog virtual machine runtime |
| **GTKWave** | Missing | Not found in PATH | Waveform viewing utility |
| **LaTeX (`pdflatex`)** | Missing | Not found in PATH | PDF compiler for IEEE report |
| **Graphviz (`dot`)** | Missing | Not found in PATH | Optional diagram rendering engine |

### Installation Instructions for Missing Tools on macOS

To install the missing open-source hardware verification toolchain via Homebrew, run:

```bash
# 1. Install Icarus Verilog (includes iverilog and vvp)
brew install icarus-verilog

# 2. Install GTKWave for viewing .vcd waveform files
brew install --cask gtkwave

# 3. Install basic LaTeX environment (or MacTeX)
brew install --cask basictex
# After basictex install, configure PATH:
# export PATH="/Library/TeX/texbin:$PATH"

# 4. (Optional) Install Graphviz for schematic rendering
brew install graphviz
```

> **Simultaneous Verification Strategy:**  
> In addition to the standard Verilog-2001 testbench (`cache_tb.v`) and compilation script (`scripts/run_sim.sh`), an automated, cycle-accurate Python simulation engine (`scripts/simulate_cache.py`) is provided. This verifies the complete 16-bit cache architecture cycle-by-cycle, tests all 12 mandatory verification cases, outputs comprehensive simulation logs, and generates standard `.vcd` waveform files immediately.

---

## 4. Current Implementation Status

- [x] **Phase A: Workspace & Tool Inspection:** Completed. Discrepancies analyzed and logged.
- [x] **Phase B: Architecture Finalization:** 16-bit Write-Through / Write-Allocate specification finalized.
- [ ] **Phase C: RTL Implementation:**
  - `cache_memory.v`: 4 cache lines, 4 bytes/line, 12-bit tag, valid bit.
  - `cache_controller.v`: 6-state Moore/Mealy FSM with clean handshakes.
  - `main_memory.v`: Byte-addressable model with 4-byte block burst read & single byte write.
  - `direct_mapped_cache.v`: Top-level structural integration.
- [ ] **Phase D: System Integration & Handshaking:** Verified port widths and signal mapping.
- [ ] **Phase E: Verification Testbench:** Self-checking `cache_tb.v` covering 12 test vectors with PASS/FAIL counters.
- [ ] **Phase F: Simulation & Waveforms:** Generated `simulation.log`, test summary, and `cache_sim.vcd`.
- [ ] **Phase G: Architectural Diagrams:** Block diagram, address slicing, FSM state diagram, read/write flowcharts.
- [ ] **Phase H: IEEE Phase I Report:** LaTeX conference paper with verified literature citations and data.
- [ ] **Phase I: GitHub Repository & README:** Professional README, commit history, and directory tree.
- [ ] **Phase J: Demonstration Video & Presentation:** 5-minute video script, checklist, and slide deck.
- [ ] **Phase K: Phase II & Interview Guide:** 30 comprehensive Q&As and architectural evolution roadmap.

---

## 5. Summary of Next Actions
1. Implement the four core synthesizable Verilog modules adhering strictly to the 16-bit Write-Through specification.
2. Develop the self-checking testbench covering all 12 test scenarios (Read Hit, Read Miss, Write Hit, Write Miss, Conflict Miss replacement on `0x0034` vs `0x0044`, byte selection).
3. Execute simulation and verify zero failure count.
4. Render architecture diagrams and author the IEEE Phase I report.
5. Finalize the 5 milestone commits and deliver complete project assets.
