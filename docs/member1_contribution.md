# Member 1 Documentation & IEEE Report Contribution

**Role:** Member 1 — Cache Architecture & Verilog Design  
**Project:** 4 KB Direct-Mapped Cache Controller with Write-Back Policy  

---

## 1. IEEE Report Section: Proposed Architecture (Draft Text)

*Copy and paste or adapt this section for the **"Proposed Solution / System Architecture"** in your IEEE Report:*

> ### III. PROPOSED SYSTEM ARCHITECTURE & RTL DESIGN
> 
> To mitigate the processor-memory performance gap, we propose a modular, synthesizable **Direct-Mapped Cache Controller** designed in Verilog HDL. The cache features a total data capacity of **4 KB** partitioned into **256 cache lines**, each having a line block size of **16 Bytes (128 bits)** corresponding to four 32-bit words.
>
> #### A. Address Mapping Scheme
> For an incoming 32-bit physical address from the processor:
> 1. **Byte Offset (`A[1:0]` - 2 bits):** Defines sub-word alignment.
> 2. **Word Offset (`A[3:2]` - 2 bits):** Multiplexes one of four 32-bit words within the 128-bit cache line.
> 3. **Line Index (`A[11:4]` - 8 bits):** Direct index addressing one of the 256 cache lines ($2^8 = 256$).
> 4. **Tag Field (`A[31:12]` - 20 bits):** Stored in the tag SRAM array to confirm line validity and address ownership ($32 - 8 - 4 = 20$ bits).
>
> #### B. Write and Allocation Policy
> The controller adopts a **Write-Back** policy with **Write-Allocate** on write misses:
> - **Write-Back:** CPU write operations update only the internal cache line and mark the associated **Dirty bit** as active (`1'b1`). Main memory is updated only when a dirty line is evicted by an incoming conflicting memory address, conserving bus bandwidth.
> - **Write-Allocate:** On a write miss, the requested block is fetched from main memory into the cache line first, after which the specified word is overwritten and the line is marked dirty.
>
> #### C. Finite State Machine (FSM) Controller
> The controller transitions across five distinct states implemented using standard non-blocking hardware constructs:
> 1. **`S_IDLE`:** Awaits CPU memory requests (`cpu_req`), latching incoming address, operation type (`cpu_rw`), and data.
> 2. **`S_COMPARE_TAG`:** Performs single-cycle hit/miss evaluation. On a hit, reads complete immediately with zero wait states and writes update the designated word. On a miss, if the old line is dirty, the FSM transitions to `S_WRITE_BACK`; otherwise, it transitions directly to `S_ALLOCATE`.
> 3. **`S_WRITE_BACK`:** Evicts the dirty cache block to main memory at `{evict_tag, req_index, 4'b0000}`.
> 4. **`S_ALLOCATE`:** Reads a 128-bit block from main memory at `{req_tag, req_index, 4'b0000}` and writes it to the data array, updating the tag and asserting valid.
> 5. **`S_UPDATE`:** Delivers the read word to the CPU or updates the write-word with CPU write data, updating the dirty flag and asserting `cpu_ready`.

---

## 2. IEEE Report Section: Individual Contributions (Member 1)

*Copy and paste this text under **"Individual Contributions - Member 1"** in the report:*

> **Member 1: Cache Architecture & Verilog RTL Design**
> - Formulated the architectural specifications of the Direct-Mapped Cache (4 KB capacity, 16-byte cache line, 20-bit tag, 8-bit index, 2-bit word offset).
> - Designed and implemented the complete synthesizable Verilog HDL codebase:
>   - `cache_defines.vh`: Defined address slicing parameters, timing macros, and FSM state encodings.
>   - `cache_tag_array.v`: Implemented the 256-entry Tag array, Valid bit array, and Dirty bit tracking logic.
>   - `cache_data_array.v`: Implemented the 4 KB Data SRAM array with sub-word multiplexing and block-refill capabilities.
>   - `cache_controller.v`: Engineered the master 5-state Mealy/Moore FSM, handshaking protocols with CPU and Memory, hit/miss detection logic, and eviction control.
> - Drafted detailed architectural block diagrams, memory mapping layouts, and state transition diagrams for the team repository and report.

---

## 3. Prototype Video Script Pointers (Under 5 Minutes)

When recording your prototype video, here is how you (Member 1) should present your portion:

1. **Self Introduction (15-20 seconds):**
   > *"Hello everyone, I am [Your Name], Member 1 of the team. My primary responsibility in this project is the Cache Architecture design and Verilog RTL implementation."*

2. **Architecture Explanation (60-90 seconds):**
   > *"For our project, we designed a 4 Kilobyte Direct-Mapped Cache Controller for 32-bit processors. Our 32-bit address is split into: a 20-bit Tag, an 8-bit Index addressing 256 lines, and a 4-bit offset where bits [3:2] select the 32-bit word within a 16-byte cache line.*  
   > *We selected a Write-Back with Write-Allocate policy. This ensures that memory writes are cached locally and only written back to main memory when a dirty line is evicted, drastically reducing bus congestion."*

3. **Verilog RTL Walkthrough (60-90 seconds):**
   > *"Our RTL structure is partitioned into three clean, synthesizable modules:*
   > 1. *`cache_tag_array.v`: Tracks 256 tags alongside Valid and Dirty bits.*
   > 2. *`cache_data_array.v`: Stores 256 lines of 128-bit data with 32-bit word multiplexing.*
   > 3. *`cache_controller.v`: Houses our 5-state FSM — IDLE, COMPARE_TAG, WRITE_BACK, ALLOCATE, and UPDATE.*  
   > *When a hit occurs, the transaction completes immediately in single-cycle turnaround. On a dirty miss, the FSM automatically evicts the old block to memory, reads the new line, updates the cache, and asserts `cpu_ready`."*

4. **Handing off to teammates:**
   > *"Now, my teammate Member 2 will demonstrate the testbench verification and simulation waveforms."*

---

## 4. Phase II Viva / Interview Questions & Model Answers

### Q1: Why did you choose a Direct-Mapped Cache instead of Set-Associative?
**Answer:**  
Direct-mapped caches have the lowest access latency, smallest silicon area, and simplest hardware implementation because there is no multiplexer or replacement policy logic (like LRU/FIFO) required to pick a way. Each memory address maps to exactly one cache line, making hit detection instantaneous.

### Q2: What is the significance of the Dirty bit?
**Answer:**  
In a Write-Back cache, when the CPU writes data to a cache line on a hit or write-allocate, only the cache is updated, not the main memory. We set the Dirty bit to `1` to indicate this discrepancy. When a miss evicts that block in the future, the controller checks the Dirty bit: if `1`, it writes the block back to main memory; if `0`, it safely discards the block without wasting memory bus cycles.

### Q3: Explain what happens during a Read Miss on a Dirty line.
**Answer:**  
1. CPU requests a read; FSM checks the tag at `req_index` in `S_COMPARE_TAG`.
2. Tag mismatch occurs (Miss), and `stored_dirty == 1`.
3. FSM latches the old tag and enters `S_WRITE_BACK`, writing the 128-bit dirty block back to main memory at `{evict_tag, req_index, 4'b0000}`.
4. Once `mem_ready` is asserted, FSM enters `S_ALLOCATE` and requests the new block from memory at `{req_tag, req_index, 4'b0000}`.
5. In `S_UPDATE`, the new block is written to cache, `dirty` is cleared to `0`, `valid` is set to `1`, the requested word is placed on `cpu_rdata`, and `cpu_ready` is pulsed.

