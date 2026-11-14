# Phase II Continuation & Architectural Roadmap

**Project:** Direct-Mapped Cache Controller Using Verilog HDL  
**Phase I Milestone:** Fully Verified 16-Bit Direct-Mapped Cache Controller (Write-Through, Write-Allocate)  
**Phase II Target:** Advanced Cache Topologies, Associativity, and Write-Back Optimization  

---

## 1. Executive Summary & Phase I Baseline

In Phase I, our team designed, implemented, and verified a synthesizable 16-bit **Direct-Mapped Cache Controller** using Verilog-2001. The Phase I system demonstrated:
- Single-cycle lookup latency on read hits.
- 100% data coherence through a Write-Through policy.
- Spatial locality exploitation via 4-byte block allocation on misses (Write-Allocate).
- Complete functional verification across 20 assertions with 0 errors.

While Phase I delivers optimal silicon area and minimal cycle delay, direct-mapped caches suffer from **conflict misses** when multiple active addresses alias to the same cache line. Phase II expands the architectural scope to resolve these limitations.

---

## 2. Phase II Planned Architectural Enhancements

```
+---------------------------------------------------------------------------------+
|                                 PHASE II ROADMAP                                |
+---------------------------------------------------------------------------------+
        |
        +---> 1. 2-Way Set-Associative Cache Architecture
        |        - 2 Sets x 2 Ways per Set (4 Cache Lines Total)
        |        - Concurrent dual-tag comparison
        |        - Elimination of ping-pong conflict thrashing on 0x0034 vs 0x0044
        |
        +---> 2. Write-Back Policy with Dirty-Bit Tracking
        |        - Writes modify only the cache line in single-cycle turnaround
        |        - Dirty bit marks modified blocks
        |        - Eviction write-back to memory occurs only for dirty lines
        |        - Re-use of architectural baseline from rtl/archive_32bit_writeback/
        |
        +---> 3. Hardware Replacement Policies
        |        - True Least Recently Used (LRU) 1-bit state machine per set
        |        - Comparison with Pseudo-LRU (Tree-PLRU) and FIFO
        |
        +---> 4. Quantitative Performance & Hit-Rate Benchmarking
        |        - Integration of synthetic memory traces (matrix multiplication, FFT)
        |        - Measurement of hit-rate improvements: Direct-Mapped vs 2-Way
        |        - Bus traffic reduction analysis: Write-Through vs Write-Back
+---------------------------------------------------------------------------------+
```

---

## 3. Detailed Architectural Evolution

### 3.1 2-Way Set-Associative Cache
In Phase II, the 4 cache lines will be grouped into **2 Sets**, each containing **2 Ways (Way 0 and Way 1)**:
- **Set 0:** Way 0 (Line 0) and Way 1 (Line 1).
- **Set 1:** Way 0 (Line 2) and Way 1 (Line 3).

#### Address Decomposition Comparison:
| Bit-Field | Phase I: Direct-Mapped | Phase II: 2-Way Set-Associative |
|---|---|---|
| **Offset** | 2 bits ($A[1:0]$, 4 bytes/line) | 2 bits ($A[1:0]$, 4 bytes/line) |
| **Index** | 2 bits ($A[3:2]$, 4 lines) | **1 bit** ($A[2]$, 2 sets) |
| **Tag** | 12 bits ($A[15:4]$) | **13 bits** ($A[15:3]$) |

#### Resolution of the Benchmark Conflict Miss:
In Phase I, `0x0034` and `0x0044` both mapped to Line 1 and caused conflict eviction.  
In Phase II:
- `0x0034` maps to Set 1 ($A[2] = 1$) and can reside in **Way 0**.
- `0x0044` also maps to Set 1 ($A[2] = 1$) and can reside concurrently in **Way 1**.  
**Result:** Both blocks reside in cache simultaneously, completely eliminating the conflict miss!

---

### 3.2 Write-Back with Dirty-Bit Tracking
To conserve memory bus bandwidth, Phase II will adopt a Write-Back policy:
1. When the CPU writes to a cached block, only the cache SRAM is updated.
2. A **Dirty Bit** associated with that line is asserted (`dirty = 1'b1`).
3. When that line is eventually evicted by an incoming miss:
   - If `dirty == 1'b1`: The controller stalls, writing the 4-byte modified block back to main memory before loading the new block.
   - If `dirty == 1'b0`: The controller discards the clean block immediately, saving memory bus cycles.

*(Note: The archived preliminary codebase preserved in `rtl/archive_32bit_writeback/` already implemented a complete 5-state Write-Back FSM with dirty tracking and will serve as our immediate reference).*

---

### 3.3 Hardware LRU Replacement Policy
For each set, a single 1-bit flip-flop `lru_bit[set]` tracks access recency:
- When Way 0 is accessed (Read/Write): `lru_bit[set] <= 1'b1` (pointing to Way 1 as least recently used).
- When Way 1 is accessed (Read/Write): `lru_bit[set] <= 1'b0` (pointing to Way 0 as least recently used).
- On a miss requiring eviction: The controller consults `lru_bit[set]` to pick the eviction victim.

---

## 4. Phase II Performance Evaluation Plan

| Metric | Phase I: Direct-Mapped Write-Through | Phase II Goal: 2-Way Write-Back | Expected Improvement |
|---|---|---|---|
| **Conflict Misses** | High on aliasing workloads | Near-zero for dual-conflict | **> 60% reduction** in conflict misses |
| **Write Bus Traffic** | 100% of CPU writes hit memory bus | Writes batched in cache | **> 70% reduction** in memory write transactions |
| **Read Hit Latency** | 2 clock cycles | 2 clock cycles | Maintained |
| **Write Hit Latency**| 4 clock cycles (Memory write-thru) | **2 clock cycles** (Cache update only) | **50% faster write hits** |
