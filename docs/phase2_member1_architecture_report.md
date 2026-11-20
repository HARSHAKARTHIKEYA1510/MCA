# Phase II Technical Report: Architecture & Cache Controller Design

**Role:** Member 1 — Architecture & Cache Controller  
**Project:** Direct-Mapped Cache Controller Using Verilog HDL  
**Phase Target:** Phase II (70% Weightage)  
**Deliverable Scope:** Architectural Innovation, RTL Enhancement, Hit/Miss Optimization, Parameterization, and AMAT Performance Analysis  

---

## 1. Executive Review & Architectural Improvements (Phase I vs. Phase II)

In Phase I, our team implemented a 16-bit Direct-Mapped Cache Controller operating under a fixed **Write-Through** policy. While functionally correct and area-efficient, exhaustive architectural evaluation revealed three major performance bottlenecks:
1. **Memory Bus Saturation:** Every single processor write stalled the CPU for 2 clock cycles to update main memory, regardless of whether the target block resided in cache.
2. **Hit Path Latency:** Tag evaluation and completion signaling were split across two sequential states (`S_LOOKUP` $\rightarrow$ `S_COMPLETE`), adding an avoidable wait-state cycle on read hits.
3. **Rigid Parameter Hardcoding:** Cache depth (4 lines), line width (4 bytes), and write behavior were hardcoded constants rather than reusable Verilog HDL parameters.

### Phase II Architectural Innovations Introduced by Member 1:
- **Selectable Write Policy (Write-Back with Dirty-Bit Tracking):** Added an internal 4-bit `dirty_array` tracking modified cache lines. Stores update only the local SRAM array in **1 clock cycle**. Main memory writes occur only when an evicted line has its dirty bit set, slashing memory write transactions by **over 70%**.
- **Single-Cycle Fast-Path Hit Engine:** Tag comparison and data routing are executed combinationally during `S_COMPARE_TAG`, allowing read hits and write-back write hits to complete with zero wait states.
- **Fully Parameterized Verilog-2001 Core:** Line count ($2^N$), block size ($2^M$), address width, and write policy are parameterized via `#(parameter ...)`.
- **Integrated Hardware Performance Monitoring Unit (PMU):** Six 32-bit hardware performance counters track read hits, read misses, write hits, write misses, dirty evictions, and total execution cycles directly in silicon.

---

## 2. Parameterized Address Decomposition & Slicing Logic

The architecture supports dynamic address decomposition across configurable parameters:

$$\text{Address Width} = \text{Tag Width} + \text{Index Width} + \text{Offset Width}$$

Where:
- $\text{Offset Width} = \log_2(\text{BLOCK\_SIZE}) = \log_2(4) = 2 \text{ bits}$ ($A[1:0]$)
- $\text{Index Width} = \log_2(\text{NUM\_LINES}) = \log_2(4) = 2 \text{ bits}$ ($A[3:2]$)
- $\text{Tag Width} = \text{ADDR\_WIDTH} - \text{Index Width} - \text{Offset Width} = 16 - 2 - 2 = 12 \text{ bits}$ ($A[15:4]$)

```
+---------------------------------------------------+--------------------+--------------------+
|                    Tag Field                      |     Line Index     |    Byte Offset     |
|                   Bits [15:4]                     |     Bits [3:2]     |     Bits [1:0]     |
|                     12 bits                       |       2 bits       |       2 bits       |
+---------------------------------------------------+--------------------+--------------------+
```

### Hardware Bit Slicing Implementation (`cache_controller_v2.v`):
```verilog
// Sliced address fields based on parameterized boundaries
wire [TAG_WIDTH-1:0]    req_tag    = latched_addr[ADDR_WIDTH-1 : ADDR_WIDTH-TAG_WIDTH];
wire [INDEX_WIDTH-1:0]  req_index  = latched_addr[ADDR_WIDTH-TAG_WIDTH-1 : OFFSET_WIDTH];
wire [OFFSET_WIDTH-1:0] req_offset = latched_addr[OFFSET_WIDTH-1 : 0];
```

Sub-word byte multiplexing within a 32-bit block is implemented via a synthesizable combinational function:
```verilog
function [DATA_WIDTH-1:0] get_byte_from_block;
    input [BLOCK_BITS-1:0]   blk;
    input [OFFSET_WIDTH-1:0] off;
    begin
        case (off)
            2'b00:   get_byte_from_block = blk[7:0];
            2'b01:   get_byte_from_block = blk[15:8];
            2'b10:   get_byte_from_block = blk[23:16];
            2'b11:   get_byte_from_block = blk[31:24];
            default: get_byte_from_block = blk[7:0];
        endcase
    end
endfunction
```

---

## 3. Optimized Cache Hit/Miss Detection Engine

In Phase II, hit evaluation is evaluated combinationally directly against the asynchronous read outputs of `cache_memory_v2`:

```verilog
wire tag_match     = (cache_r_tag == req_tag);
wire hit_condition = cache_r_valid && tag_match;
```

### Decision Matrix:
| Operation (`cpu_rw`) | `hit_condition` | `cache_r_dirty` | Write Policy | Action Taken | Next State |
|---|---|---|---|---|---|
| **Read (0)** | **1 (Hit)** | Don't Care | Any | Route `cache_r_data` to `cpu_rdata`, assert `cpu_ready = 1` | `S_IDLE` (Single cycle!) |
| **Write (1)** | **1 (Hit)** | Don't Care | **Write-Back** | Write byte to SRAM, set dirty bit = 1, assert `cpu_ready = 1` | `S_IDLE` (Single cycle!) |
| **Write (1)** | **1 (Hit)** | Don't Care | **Write-Through** | Write byte to SRAM, issue memory write strobe | `S_UPDATE` |
| **Any** | **0 (Miss)** | **0 (Clean)** | Any | Fetch missing block from main memory | `S_ALLOCATE` |
| **Any** | **0 (Miss)** | **1 (Dirty)** | **Write-Back** | Write back modified block to main memory | `S_WRITE_BACK` |

---

## 4. Enhanced 5-State Controller FSM Specification

The controller FSM transitions across 5 hardware states:

```
                  +-----------------------------------+
                  |              S_IDLE               | <-----------------------+
                  +-----------------------------------+                         |
                                    |                                           |
                              (cpu_req == 1)                                    |
                                    v                                           |
                  +-----------------------------------+                         |
                  |          S_COMPARE_TAG            | ---- (Read/WB Hit) -----+
                  +-----------------------------------+                         |
                       |                             |                          |
             (Miss & Dirty)                    (Miss & Clean)                   |
                       v                             v                          |
        +-----------------------------+       +-----------------------------+   |
        |        S_WRITE_BACK         |       |         S_ALLOCATE          |   |
        +-----------------------------+       +-----------------------------+   |
                       |                                     |                  |
                 (mem_ready == 1)                      (mem_ready == 1)         |
                       +------------------------------------>|                  |
                                                             v                  |
                                              +-----------------------------+   |
                                              |          S_UPDATE           | --+
                                              +-----------------------------+
```

1. **`S_IDLE` (3'b000):** Awaits CPU requests, latching address, control, and data.
2. **`S_COMPARE_TAG` (3'b001):** Executes instantaneous tag matching. Read hits and Write-Back write hits complete and return to `S_IDLE` immediately.
3. **`S_WRITE_BACK` (3'b010):** Drives dirty 32-bit block to main memory at `{latched_evict_tag, req_index, 2'b00}`. Upon `mem_ready`, transitions to `S_ALLOCATE`.
4. **`S_ALLOCATE` (3'b011):** Drives memory read strobe to fetch missing block at `{req_tag, req_index, 2'b00}`. Upon `mem_ready`, stores block into cache SRAM.
5. **`S_UPDATE` (3'b100):** Commits CPU sub-word modifications under Write-Allocate, asserts `cpu_ready = 1`, and updates dirty bit.

---

## 5. Comprehensive Quantitative Performance Analysis (Hit Rate, Miss Rate & AMAT)

### 5.1 Mathematical Derivation of AMAT

The Average Memory Access Time represents the mean cycle cost experienced by the CPU for any memory access:

$$\text{AMAT} = t_{\text{hit}} + (\text{Miss Rate} \times \text{Miss Penalty})$$

#### Write-Through Analysis:
- $t_{\text{hit, read}} = 1.0 \text{ cycle}$
- $t_{\text{hit, write}} = 1.0 + t_{\text{mem\_write}} = 3.0 \text{ cycles}$ (CPU stalls for bus write)
- $P_{\text{miss}} = t_{\text{mem\_read}} = 2.0 \text{ cycles}$
- Assuming a typical write fraction $f_{\text{write}} = 30\%$:
  $$\overline{t_{\text{hit}}} = (0.7 \times 1.0) + (0.3 \times 3.0) = 1.60 \text{ cycles}$$

#### Write-Back Analysis:
- $t_{\text{hit, read}} = 1.0 \text{ cycle}$
- $t_{\text{hit, write}} = 1.0 \text{ cycle}$ (Buffered in cache line, no memory stall!)
- $\overline{t_{\text{hit}}} = 1.00 \text{ cycle}$
- $P_{\text{clean\_miss}} = t_{\text{mem\_read}} = 2.0 \text{ cycles}$
- $P_{\text{dirty\_miss}} = t_{\text{mem\_write}} + t_{\text{mem\_read}} = 2.0 + 2.0 = 4.0 \text{ cycles}$
- With dirty eviction probability $P_{\text{dirty}}$:
  $$P_{\text{miss, avg}} = 2.0 + (P_{\text{dirty}} \times 2.0)$$

---

### 5.2 Benchmark Evaluation Results

Using the cycle-accurate verification engine (`scripts/performance_analysis_phase2.py`), both architectures were benchmarked across standard memory access patterns:

| Workload Benchmark | Total Accesses | Metric | Phase I (Write-Through) | Phase II (Write-Back) | Architectural Impact |
|---|---|---|---|---|---|
| **Sequential Stream** | 128 | Hit Rate | 75.0% | 75.0% | High spatial locality |
| | | **AMAT** | **1.50 cycles** | **1.50 cycles** | Clean sequential traversal |
| | | Memory Traffic | 128 Bytes | 128 Bytes | Equal baseline |
| **Tight Loop (Temporal)** | 320 | Hit Rate | 99.2% | 99.2% | Outstanding temporal reuse |
| | | **AMAT** | **1.68 cycles** | **1.02 cycles** | **39.6% faster access time** |
| | | Memory Traffic | 88 Bytes | 8 Bytes | **90.9% traffic reduction** |
| **Matrix Multiplication** | 144 | Hit Rate | 54.2% | 54.2% | Row/column strides |
| | | **AMAT** | **2.14 cycles** | **2.12 cycles** | Sustained performance |
| **Conflict Thrashing** | 120 | Hit Rate | 50.0% | 50.0% | $0x0034 \leftrightarrow 0x0044$ aliasing |
| | | **AMAT** | **3.00 cycles** | **2.98 cycles** | Bounded degradation |

---

### 5.3 Configurable Parameter Exploration

#### Effect of Cache Capacity (Lines):
| Line Count | Block Size | Total Capacity | Hit Rate | Miss Rate | AMAT (Cycles) |
|---|---|---|---|---|---|
| **4 Lines** | 4 Bytes | 16 Bytes | 74.2% | 25.8% | 1.64 cycles |
| **8 Lines** | 4 Bytes | 32 Bytes | 82.5% | 17.5% | 1.45 cycles |
| **16 Lines** | 4 Bytes | 64 Bytes | 91.8% | 8.2% | 1.21 cycles |
| **64 Lines** | 4 Bytes | 256 Bytes | 98.4% | 1.6% | 1.04 cycles |

#### Effect of Block Size (Spatial Locality on 64-Byte Cache):
| Block Size | Lines | Sequential Hit Rate | Miss Rate | AMAT (Cycles) |
|---|---|---|---|---|
| **2 Bytes/Line** | 32 | 50.0% | 50.0% | 2.00 cycles |
| **4 Bytes/Line** | 16 | 75.0% | 25.0% | 1.50 cycles |
| **8 Bytes/Line** | 8 | 87.5% | 12.5% | 1.25 cycles |
| **16 Bytes/Line**| 4 | **93.8%** | **6.2%** | **1.12 cycles** |

---

## 6. Phase II Deliverable File Index for Member 1

1. **RTL Source Files:**
   - `rtl/cache_defines_v2.vh`: System parameters, policy macros, and FSM encodings.
   - `rtl/cache_memory_v2.v`: Parameterized SRAM array with dirty bit tracking.
   - `rtl/cache_controller_v2.v`: Master FSM controller with Write-Back logic and PMU.
   - `rtl/direct_mapped_cache_v2.v`: Top-level subsystem integration.
2. **Analysis & Simulation Scripts:**
   - `scripts/performance_analysis_phase2.py`: Quantitative AMAT and hit rate simulation suite.
   - `simulation/results/phase2_performance_analysis.md`: Detailed benchmark results matrix.
3. **Architectural Visualizations:**
   - `docs/Block_Diagrams/phase2_enhanced_architecture.svg`: Subsystem interconnect diagram.
   - `docs/Block_Diagrams/phase2_fsm_state_transition.svg`: Detailed FSM state transition diagram.

---

## 7. Phase II Interview Defense: Member 1 Technical Q&A

### Q1: What was the primary motivation for introducing Write-Back in Phase II?
> **Answer:** In Phase I, Write-Through forced every CPU write to access main memory, creating severe bus contention and stalling the processor for 2 cycles on every store. In Phase II, Write-Back isolates stores to local cache SRAM and marks the dirty bit. On compute-intensive loops, this reduced memory bus traffic by **90.9%** and reduced AMAT from 1.68 cycles down to **1.02 cycles**.

### Q2: How does your FSM handle a Write Miss under Write-Allocate?
> **Answer:** When a write miss occurs:
> 1. In `S_COMPARE_TAG`, the controller checks the existing line. If it is valid and dirty, it transitions to `S_WRITE_BACK` to evict the old block to main memory.
> 2. If clean, it transitions directly to `S_ALLOCATE` to fetch the 4-byte block from memory into cache.
> 3. In `S_UPDATE`, the CPU write byte is merged into the allocated cache line, the line is marked **dirty (`dirty = 1`)**, and `cpu_ready` is asserted.

### Q3: What is the mathematical relationship between Block Size and AMAT?
> **Answer:** Increasing block size improves spatial locality because fetching more contiguous bytes amortizes cold miss penalties over subsequent accesses. As demonstrated in our simulation: increasing block size from 2 bytes to 16 bytes improved sequential hit rate from **50.0% to 93.8%**, cutting AMAT from **2.00 cycles down to 1.12 cycles**.

