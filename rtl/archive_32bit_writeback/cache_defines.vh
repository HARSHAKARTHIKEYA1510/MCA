// ============================================================================
// File: cache_defines.vh
// Project: Direct-Mapped Cache Controller (MCA Project)
// Module: Architecture Global Definitions & Parameters
// Description: Global parameters, bit widths, and FSM state encodings
// ============================================================================

`ifndef CACHE_DEFINES_VH
`define CACHE_DEFINES_VH

// ----------------------------------------------------------------------------
// System & Addressing Parameters
// ----------------------------------------------------------------------------
`define ADDR_WIDTH          32          // 32-bit CPU memory address
`define DATA_WIDTH          32          // 32-bit CPU data bus width
`define LINE_WIDTH          128         // 128-bit Cache Line (4 words = 16 bytes)
`define WORDS_PER_LINE      4           // 4 words per cache block
`define NUM_LINES           256         // 256 cache lines (sets in direct-mapped)
`define INDEX_WIDTH         8           // 8-bit index (2^8 = 256 lines)
`define OFFSET_WIDTH        4           // 4-bit byte offset (2^4 = 16 bytes)
`define WORD_OFFSET_WIDTH   2           // 2-bit word offset (bits [3:2])
`define TAG_WIDTH           20          // 32 - 8 - 4 = 20 bits tag

// Address slicing macros
`define ADDR_TAG            31:12       // Tag bits [31:12]
`define ADDR_INDEX          11:4        // Line index bits [11:4]
`define ADDR_WORD_OFFSET    3:2         // Word select within line [3:2]
`define ADDR_BYTE_OFFSET    1:0         // Byte select within word [1:0]

// ----------------------------------------------------------------------------
// Controller FSM State Encodings (One-hot or binary)
// ----------------------------------------------------------------------------
`define STATE_WIDTH         3

`define S_IDLE              3'b000      // Awaiting CPU request
`define S_COMPARE_TAG       3'b001      // Tag check & hit/miss evaluation
`define S_WRITE_BACK        3'b010      // Evicting dirty line to main memory
`define S_ALLOCATE          3'b011      // Fetching requested line from main memory
`define S_UPDATE            3'b100      // Updating cache array and completing CPU transaction

// ----------------------------------------------------------------------------
// Operation Encodings
// ----------------------------------------------------------------------------
`define OP_READ             1'b0        // CPU Read operation
`define OP_WRITE            1'b1        // CPU Write operation

`endif // CACHE_DEFINES_VH

