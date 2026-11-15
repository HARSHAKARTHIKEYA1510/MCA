# Presentation Slide Deck: Direct-Mapped Cache Controller Using Verilog HDL

**Project Domain:** Computer Architecture and Digital Logic Design  
**Academic Level:** College Phase I Project Evaluation  
**Group:** Group Alpha (Newton School of Technology, Rishihood University)  
**Team Members:** Palaparthi Harsha Karthikeya, Dakarapu Hemamdhar nath, Akshay Y  

---

## Slide 1: Title & Team Introduction
### Design and Implementation of a Direct-Mapped Cache Controller Using Verilog HDL
- **Course / Project:** Microprocessors & Computer Architecture (MCA)
- **Institution:** Newton School of Technology, Rishihood University
- **Group Name:** Group Alpha (Registered: 10/16/2026 18:56:58)
- **Target Architecture:** 16-Bit Byte-Addressable Architecture
- **Implementation Standard:** Verilog-2001 (IEEE 1364-2001)
- **Team Composition (3 Members):**
  - **Member 1 (Palaparthi Harsha Karthikeya - `2401010313`):** Lead Architecture & Verilog RTL Design
  - **Member 2 (Dakarapu Hemamdhar nath - `2401010137`):** Hardware Verification & Simulation Suite
  - **Member 3 (Akshay Y - `2401020008`):** Memory Subsystem, System Integration & IEEE Report
- *Administrative Note:* Formally registered 3-member team (Group Alpha) flagged for faculty review.

---

## Slide 2: Problem Statement & Motivation
### The Processor-Memory Speed Disparity
- **The Memory Wall:** Processor execution clock frequencies operate orders of magnitude faster than off-chip DRAM.
- **Latency Penalty:** CPU cores stall for tens to hundreds of cycles awaiting operands.
- **Locality Principles:**
  - *Temporal Locality:* Addresses accessed recently are likely to be accessed again soon.
  - *Spatial Locality:* Addresses physically adjacent to recent accesses are likely to be needed next.
- **Solution:** A high-speed SRAM cache controller acting as an intelligent intermediary.

---

## Slide 3: Hardware Architecture Specifications
### Parameter Breakdown
| Parameter | Value | Architectural Purpose |
|---|---|---|
| **Organization** | Direct-Mapped (1-Way) | Lowest silicon area, single-cycle lookup |
| **Address Width** | 16 Bits | 64 KB addressable memory space |
| **Data Width** | 8 Bits | Byte-level operations |
| **Cache Lines** | 4 Lines | 2-bit Line Index ($A[3:2]$) |
| **Block Size** | 4 Bytes (32 Bits) | Spatial fetch unit ($A[1:0]$) |
| **Total Capacity** | 16 Bytes | $4 \times 4$ Bytes |
| **Tag Width** | 12 Bits | High-order block address ($A[15:4]$) |
| **Write Policy** | Write-Through | Immediate memory coherence (No Dirty Bits) |
| **Allocation Policy** | Write-Allocate | Block fetched on write miss |

---

## Slide 4: 16-Bit Address Decomposition
### Bit-Field Partitioning:
```
+------------------------------------------+------------------+------------------+
|               Tag [15:4]                 |   Index [3:2]    |   Offset [1:0]   |
|                 12 bits                  |      2 bits      |      2 bits      |
+------------------------------------------+------------------+------------------+
```
- **Byte Offset (`A[1:0]` - 2 bits):** Selects byte 0, 1, 2, or 3 within the 4-byte cache line.
- **Line Index (`A[3:2]` - 2 bits):** Directly decodes Line 0, Line 1, Line 2, or Line 3.
- **Tag Field (`A[15:4]` - 12 bits):** Stored in Tag array, compared for hit determination.

### Concrete Benchmark Mapping:
- `0x0034`: Tag `0x003`, Index `1`, Offset `0` $\rightarrow$ Cold Miss, fetches block `0xA0..0xA3`.
- `0x0035`: Tag `0x003`, Index `1`, Offset `1` $\rightarrow$ Spatial Locality Hit (`0xA1`).
- `0x0044`: Tag `0x004`, Index `1`, Offset `0` $\rightarrow$ **Conflict Miss** (Aliases to Line 1!).

---

## Slide 5: System Block Diagram & Modular Hierarchy
### Synthesizable Verilog Entities
```
   +-------------------------------------------------------------+
   |                     direct_mapped_cache                     |
   |                                                             |
   |   +--------------------+          +---------------------+   |
   |   |  cache_controller  |<-------->|    cache_memory     |   |
   |   |   (6-State FSM)    |          | (4 Lines x 4 Bytes) |   |
   |   +--------------------+          +---------------------+   |
   +-------------------------------------------------------------+
               |
               v (Mem Bus: 16b Addr, 32b Block, 8b WData, Req, RW, Ready)
   +-------------------------------------------------------------+
   |                         main_memory                         |
   |           (64 KB Secondary Storage, 2-Cycle Latency)        |
   +-------------------------------------------------------------+
```
- **Clean Signal Separation:** Distinct CPU bus, internal cache SRAM bus, and memory bus.

---

## Slide 6: Finite State Machine (FSM) Design
### 6 Deterministic Controller States
1. **`S_IDLE` (`3'b000`):** Listens for `cpu_req = 1`, latches transaction inputs.
2. **`S_LOOKUP` (`3'b001`):** Compares tags:
   - *Read Hit:* Serviced in 2 cycles $\rightarrow$ `S_COMPLETE`.
   - *Write Hit:* Cache updated $\rightarrow$ `S_WRITE_THROUGH` to memory.
   - *Miss:* Transitions to `S_READ_MISS`.
3. **`S_READ_MISS` (`3'b010`):** Issues burst 4-byte block read to main memory.
4. **`S_ALLOCATE` (`3'b011`):** Writes block, tag, and valid bit into SRAM.
5. **`S_WRITE_THROUGH` (`3'b100`):** Writes byte to main memory, awaits `mem_ready`.
6. **`S_COMPLETE` (`3'b101`):** Pulses `cpu_ready = 1` for 1 cycle, returns to `S_IDLE`.

---

## Slide 7: Verification Suite & Simulation Results
### 100% Pass Rate Across 20 Assertions & 12 Scenarios
- **Cold Miss (`0x0034`):** Memory block loaded correctly $\rightarrow$ **PASS**.
- **Spatial Locality (`0x0035`):** Consecutive byte hit $\rightarrow$ **PASS**.
- **Temporal Locality (`0x0034`):** Re-read cache hit $\rightarrow$ **PASS**.
- **Write Hit & Memory Coherence (`0x0035`):** Cache and memory verified with `0x55` $\rightarrow$ **PASS**.
- **Write Miss (`0x0028`):** Allocated and written with `0x77` $\rightarrow$ **PASS**.
- **Conflict Miss (`0x0044`):** Evicts `0x0034` due to tag mismatch on Line 1 $\rightarrow$ **PASS**.
- **Line Replacement Verification (`0x0034`):** Re-access triggers miss confirming eviction $\rightarrow$ **PASS**.
- **All 4 Offsets Tested:** Offsets 0, 1, 2, 3 verified $\rightarrow$ **PASS**.
- **Multi-line Concurrent Access:** Back-to-back hits across Lines 0, 1, 2, 3 $\rightarrow$ **PASS**.

---

## Slide 8: Conflict Miss Analysis (`0x0034` vs `0x0044`)
### The Direct-Mapped Trade-off
- Both addresses map to Cache Line 1 because $A[3:2] = 2\text{'b01}$.
- When accessing `0x0044`, Tag `0x004` mismatches stored Tag `0x003`.
- **Under Write-Through:** Line 1 was already synchronized with memory; therefore, it is evicted immediately without write-back delays.
- New block `0x0044--0x0047` is installed.
- Subsequent access to `0x0034` proves the eviction by missing and reloading.

---

## Slide 9: Phase II Roadmap & Future Scope
### Moving Toward Phase II
1. **2-Way Set-Associative Cache:** Partition lines into sets of 2 ways to resolve conflict collisions.
2. **Write-Back Policy with Dirty Bits:** Reduce memory bus bandwidth consumption by writing to memory only upon eviction.
3. **LRU Replacement Strategy:** Implement Least Recently Used hardware way selection.
4. **Hit-Rate Benchmarking:** Measure hardware performance against real RISC processor memory trace workloads.

---

## Slide 10: Conclusion & Deliverables Summary
### Ready for Submission & Defense
- [x] Complete Synthesizable Verilog RTL (`direct_mapped_cache.v`, `cache_controller.v`, etc.).
- [x] Automated, self-checking testbench with 100% assertion pass rate.
- [x] Authentic VCD waveforms and simulation logs.
- [x] Complete IEEE Conference Phase I Report (`main.tex`, `references.bib`, `IEEE_report.pdf`).
- [x] 30-Question technical viva/interview preparation guide.
- [x] 5-minute prototype demonstration video script.
- **Thank you! Questions and Discussion.**
