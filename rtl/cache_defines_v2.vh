// ============================================================================
// File: cache_defines_v2.vh
// Project: Direct-Mapped Cache Controller (Phase II Enhancement)
// Role: Member 1 - Architecture & Cache Controller
// Description: Global parameters, policy definitions, address slicing macros,
//              and FSM state encodings for Phase II enhanced cache controller.
// ============================================================================

`ifndef CACHE_DEFINES_V2_VH
`define CACHE_DEFINES_V2_VH

// ----------------------------------------------------------------------------
// Write Policies
// ----------------------------------------------------------------------------
`define POLICY_WRITE_THROUGH 1'b0
`define POLICY_WRITE_BACK    1'b1

// ----------------------------------------------------------------------------
// Operation Encodings
// ----------------------------------------------------------------------------
`define OP_READ              1'b0
`define OP_WRITE             1'b1

// ----------------------------------------------------------------------------
// Controller FSM State Encodings (Phase II Optimized 5-State Engine)
// ----------------------------------------------------------------------------
`define S_IDLE               3'b000  // Awaiting CPU access request
`define S_COMPARE_TAG        3'b001  // Simultaneous tag compare & hit/miss evaluation
`define S_WRITE_BACK         3'b010  // Flushing dirty block to main memory (Write-Back)
`define S_ALLOCATE           3'b011  // Reading missing block from main memory
`define S_UPDATE             3'b100  // Committing line update & signaling CPU ready

// ----------------------------------------------------------------------------
// Default Hardware Configuration Parameters
// ----------------------------------------------------------------------------
`define DEFAULT_ADDR_WIDTH   16      // 16-bit physical address space (64 KB)
`define DEFAULT_DATA_WIDTH   8       // 8-bit CPU data bus
`define DEFAULT_BLOCK_SIZE   4       // 4 bytes per cache line
`define DEFAULT_NUM_LINES    4       // 4 cache lines (16 bytes total capacity)
`define DEFAULT_OFFSET_WIDTH 2       // log2(4) = 2 bits
`define DEFAULT_INDEX_WIDTH  2       // log2(4) = 2 bits
`define DEFAULT_TAG_WIDTH    12      // 16 - 2 - 2 = 12 bits

`endif // CACHE_DEFINES_V2_VH

