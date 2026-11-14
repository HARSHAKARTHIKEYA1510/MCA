# Hardware Architecture Specification: 16-Bit Direct-Mapped Cache Controller

**Project Domain:** Computer Architecture and Digital Logic Design  
**Target Specification:** 16-bit Byte-Addressable Architecture  
**Hardware Description Language:** Verilog-2001 (IEEE 1364-2001)  
**Target Platform:** Synthesizable FPGA / ASIC / Icarus Verilog  

---

## 1. Architectural Overview & Design Parameters

The system implements a high-performance **Direct-Mapped Cache Controller** designed to interface between an 8-bit processing unit (CPU) and a slower secondary memory (Main Memory). 

The cache architecture utilizes a **Write-Through** policy coupled with a **Write-Allocate** policy to maintain strict memory coherence, eliminate the need for dirty-bit tracking, and optimize spatial and temporal locality.

### Table 1: Core Architectural Parameters
| Architectural Parameter | Hardware Specification | Notes / Derivation |
|---|---|---|
| **Cache Organization** | Direct-Mapped (1-Way Associative) | Exactly one cache line per memory address |
| **Address Bus Width** | 16 bits ($A[15:0]$) | $2^{16} = 65,536$ addressable bytes in main memory |
| **Data Bus Width (CPU)** | 8 bits ($D[7:0]$) | Single-byte transfers between CPU and Cache |
| **Number of Cache Lines** | 4 lines | Number of sets $S = 4$ ($2^2$) |
| **Line / Block Size** | 4 bytes (32 bits) | Spatial locality fetch unit |
| **Cache Data Capacity** | 16 bytes | $4 \text{ lines} \times 4 \text{ bytes/line} = 16 \text{ bytes}$ |
| **Tag Field Width** | 12 bits ($Tag[11:0]$) | $16 - 2 - 2 = 12 \text{ bits}$ |
| **Index Field Width** | 2 bits ($Index[1:0]$) | $\log_2(4) = 2 \text{ bits}$ |
| **Offset Field Width** | 2 bits ($Offset[1:0]$) | $\log_2(4) = 2 \text{ bits}$ |
| **Valid Bits** | 1 bit per line (4 bits total) | Indicates presence of valid data |
| **Dirty Bits** | None (0 bits) | Not required under Write-Through policy |
| **Write Policy** | Write-Through | Every write updates both Cache and Main Memory |
| **Write Allocation Policy** | Write-Allocate | Write misses fetch the target block before updating |
| **Implementation Standard** | Verilog-2001 | Synthesizable RTL, verified on Icarus Verilog |

---

## 2. Memory Address Decomposition

Every 16-bit memory address supplied by the CPU core is partitioned into three disjoint bit-fields:

$$\text{16-Bit Address } A[15:0] = \underbrace{\text{Tag } [15:4]}_{12\text{ bits}} \;+\; \underbrace{\text{Index } [3:2]}_{2\text{ bits}} \;+\; \underbrace{\text{Offset } [1:0]}_{2\text{ bits}}$$

```
+------------------------------------------+------------------+------------------+
|               Tag [15:4]                 |   Index [3:2]    |   Offset [1:0]   |
|                 12 bits                  |      2 bits      |      2 bits      |
+------------------------------------------+------------------+------------------+
```

### 2.1 Bit-Field Definitions
1. **Byte Offset (`A[1:0]`, 2 bits):**
   - Addresses one of the four individual bytes ($B_0, B_1, B_2, B_3$) residing inside a 4-byte cache block.
   - Values:
     - `2'b00`: Byte 0 (Least Significant Byte)
     - `2'b01`: Byte 1
     - `2'b10`: Byte 2
     - `2'b11`: Byte 3 (Most Significant Byte)
2. **Line Index (`A[3:2]`, 2 bits):**
   - Directly selects one of the 4 cache lines (Line 0, Line 1, Line 2, Line 3).
   - Values:
     - `2'b00`: Line 0
     - `2'b01`: Line 1
     - `2'b10`: Line 2
     - `2'b11`: Line 3
3. **Tag Field (`A[15:4]`, 12 bits):**
   - Represents the upper memory address page bits. Stored inside the cache tag register array and compared against incoming addresses to detect hits or misses.

---

## 3. Concrete Numerical Examples & Conflict Analysis

### Table 2: Address Decomposition for Benchmark Test Addresses
| Hex Address | 16-Bit Binary Representation | Tag (`[15:4]`) | Index (`[3:2]`) | Offset (`[1:0]`) | Target Cache Line |
|---|---|---|---|---|---|
| **`0x0034`** | `0000 0000 0011 0100` | `12'h003` (`000000000011`) | `2'b01` | `2'b00` | **Line 1 (Byte 0)** |
| **`0x0035`** | `0000 0000 0011 0101` | `12'h003` (`000000000011`) | `2'b01` | `2'b01` | **Line 1 (Byte 1)** |
| **`0x0036`** | `0000 0000 0011 0110` | `12'h003` (`000000000011`) | `2'b01` | `2'b10` | **Line 1 (Byte 2)** |
| **`0x0037`** | `0000 0000 0011 0111` | `12'h003` (`000000000011`) | `2'b01` | `2'b11` | **Line 1 (Byte 3)** |
| **`0x0044`** | `0000 0000 0100 0100` | `12'h004` (`000000000100`) | `2'b01` | `2'b00` | **Line 1 (Byte 0)** |

### 3.1 Spatial Locality Demonstration (`0x0034` – `0x0037`)
When an initial read request occurs for address `0x0034`, a **Cold Miss (Compulsory Miss)** occurs because the cache starts uninitialized (`valid = 0`).
- The controller fetches the complete 4-byte block spanning memory addresses `0x0034`, `0x0035`, `0x0036`, and `0x0037`.
- The block is stored into **Line 1**, the tag `12'h003` is saved, and `valid[1]` is asserted.
- Subsequent reads to `0x0035`, `0x0036`, and `0x0037` immediately result in **Cache Hits** requiring zero memory cycles. This directly validates spatial locality.

### 3.2 Conflict Miss & Replacement Demonstration (`0x0034` vs `0x0044`)
Both `0x0034` and `0x0044` have identical index bits:
- $A[3:2] = 2\text{'b01} \implies \text{Line 1}$.
However, their tags differ:
- For `0x0034`: Tag = `12'h003`.
- For `0x0044`: Tag = `12'h004`.

Because the cache is **direct-mapped**, memory addresses with identical index bits map to the exact same physical line. When the CPU accesses `0x0044` after `0x0034`:
1. The controller indexes Line 1.
2. The valid bit is active (`1'b1`), but the stored tag (`12'h003`) does not match the requested tag (`12'h004`).
3. This is identified as a **Conflict Miss**.
4. The controller evicts the old block (`0x0034–0x0037`), fetches the new 4-byte block (`0x0044–0x0047`), overwrites Line 1, and updates the stored tag to `12'h004`.
5. Because the policy is **Write-Through**, the previous block in Line 1 was already synchronized with main memory; hence, no dirty write-back is necessary before eviction!

---

## 4. Hardware Modular Hierarchy

The design is decomposed into four synthesizable, highly modular Verilog modules:

```
+---------------------------------------------------------------------------------+
|                               direct_mapped_cache                               |
|                         (Top-Level System Interconnect)                         |
|                                                                                 |
|  +-----------------------------+             +-------------------------------+  |
|  |      cache_controller       |             |         cache_memory          |  |
|  |                             |             |                               |  |
|  | - 6-State Master FSM        |<----------->| - 4 x 4-Byte Data Array       |  |
|  | - Address Slicing           |             | - 4 x 12-Bit Tag Array        |  |
|  | - Hit / Miss Detection      |             | - 4 x 1-Bit Valid Flags       |  |
|  | - Handshake Management      |             | - Byte & Block Access Ports   |  |
|  +-----------------------------+             +-------------------------------+  |
+---------------------------------------------------------------------------------+
                                      |
                                      | (Memory Bus: Addr, Req, RW, WData, RDataBlock)
                                      v
+---------------------------------------------------------------------------------+
|                                  main_memory                                    |
| - Byte-addressable storage (64 KB space)                                        |
| - 4-Byte burst block read port                                                  |
| - Single-byte write port with configurable latency emulation                    |
| - Completion acknowledge strobe (mem_ready)                                     |
+---------------------------------------------------------------------------------+
```

---

## 5. Master Finite State Machine (FSM) Specification

The cache controller is implemented as an explicit 6-state Moore/Mealy hybrid FSM:

```
                     +--------------+
                     |    S_IDLE    |<-----------------------------------+
                     +--------------+                                    |
                            |                                            |
                            | cpu_req == 1                               |
                            v                                            |
                     +--------------+                                    |
                     |   S_LOOKUP   |                                    |
                     +--------------+                                    |
                       /          \                                      |
         Hit == 1     /            \  Hit == 0                           |
         (Read Hit)  /              \ (Read/Write Miss)                  |
                    /                \                                   |
                   v                  v                                  |
            +------------+     +--------------+                          |
            | S_COMPLETE |     | S_READ_MISS  |                          |
            +------------+     +--------------+                          |
                 ^                    |                                  |
                 |                    | mem_ready == 1                   |
                 |                    v                                  |
                 |             +--------------+                          |
                 |             |  S_ALLOCATE  |                          |
                 |             +--------------+                          |
                 |                    |                                  |
                 |       +------------+------------+                     |
                 |       |                         |                     |
                 |       | Read Miss               | Write Miss          |
                 |       v                         v                     |
                 |  (Direct to Complete)    +------------------+         |
                 |                          | S_WRITE_THROUGH  |         |
                 |                          +------------------+         |
                 |                                 |                     |
                 |                                 | mem_ready == 1      |
                 |                                 v                     |
                 +---------------------------------+                     |
                 |                                                       |
                 | (Write Hit Path: S_LOOKUP -> S_WRITE_THROUGH)         |
                 +-------------------------------------------------------+
```

### 5.1 Detailed FSM State Transitions
1. **`S_IDLE` (`3'b000`):**
   - Listens for `cpu_req == 1'b1`.
   - Latches `cpu_addr`, `cpu_rw`, and `cpu_wdata`.
   - If `cpu_req` asserted, advances to `S_LOOKUP`.
2. **`S_LOOKUP` (`3'b001`):**
   - Reads tag and valid bit for indexed line.
   - Evaluates: `is_hit = (stored_valid == 1'b1) && (stored_tag == req_tag)`.
   - **Branch Decisions:**
     - **Read Hit (`is_hit && !req_rw`):** Direct transition to `S_COMPLETE` (`cpu_hit = 1`, `cpu_rdata = cache_byte`).
     - **Write Hit (`is_hit && req_rw`):** Cache byte is updated immediately; transition to `S_WRITE_THROUGH` to update main memory (`cpu_hit = 1`).
     - **Read Miss (`!is_hit && !req_rw`):** Transition to `S_READ_MISS` (`cpu_hit = 0`).
     - **Write Miss (`!is_hit && req_rw`):** Transition to `S_READ_MISS` to allocate block first under Write-Allocate (`cpu_hit = 0`).
3. **`S_READ_MISS` (`3'b010`):**
   - Drives `mem_req = 1'b1`, `mem_rw = 1'b0` (Read Block), `mem_addr = {req_tag, req_index, 2'b00}`.
   - Awaits `mem_ready == 1'b1`. Once asserted, advances to `S_ALLOCATE`.
4. **`S_ALLOCATE` (`3'b011`):**
   - Stores the fetched 4-byte block (`mem_rdata_block`) into cache line `req_index`.
   - Writes `req_tag` and sets `valid = 1'b1`.
   - **Branch Decisions:**
     - **If Read Miss:** Data is now in cache; transition to `S_COMPLETE`.
     - **If Write Miss:** Target byte in cache is updated with `req_wdata`; transition to `S_WRITE_THROUGH` to propagate write to main memory.
5. **`S_WRITE_THROUGH` (`3'b100`):**
   - Drives `mem_req = 1'b1`, `mem_rw = 1'b1` (Write Byte), `mem_addr = req_addr`, `mem_wdata = req_wdata`.
   - Awaits `mem_ready == 1'b1`. Once memory write commits, advances to `S_COMPLETE`.
6. **`S_COMPLETE` (`3'b101`):**
   - Asserts `cpu_ready = 1'b1` for one clock cycle.
   - For read operations, drives `cpu_rdata`.
   - Returns to `S_IDLE`.

---

## 6. Bus Interface & Handshaking Protocol

### 6.1 CPU Handshake
- The CPU presents `cpu_addr`, `cpu_rw`, and `cpu_wdata` (for writes) alongside `cpu_req = 1'b1`.
- The CPU holds `cpu_req` high until `cpu_ready` is asserted.
- Upon assertion of `cpu_ready`, the CPU latches `cpu_rdata` (if reading) and deasserts `cpu_req`.
- `cpu_hit` indicates whether the transaction succeeded from cache without requiring memory stall cycles.

### 6.2 Main Memory Handshake
- The Controller issues `mem_req = 1'b1` with target `mem_addr` and operation `mem_rw`.
- Main memory simulates access latency (e.g., 2 clock cycles) before pulsing `mem_ready = 1'b1`.
- On read block operations (`mem_rw = 0`), main memory supplies 32 bits on `mem_rdata_block`.
- On write operations (`mem_rw = 1`), main memory writes `mem_wdata` into address `mem_addr`.
