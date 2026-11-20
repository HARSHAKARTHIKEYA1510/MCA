// ============================================================================
// File: direct_mapped_cache_v2.v
// Project: Direct-Mapped Cache Controller (Phase II Enhancement)
// Role: Member 1 - Architecture & Cache Controller
// Description: Enhanced Top-Level Cache Subsystem integrating:
//              1. cache_controller_v2: Parameterized 5-state FSM with Write-Back
//                 support, single-cycle hit path, and PMU monitoring.
//              2. cache_memory_v2: Configurable Tag, Valid, Dirty, and Data SRAM.
// Standard: Verilog-2001 (IEEE 1364-2001)
// ============================================================================

`timescale 1ns / 1ps
`include "cache_defines_v2.vh"

module direct_mapped_cache_v2 #(
    parameter ADDR_WIDTH   = `DEFAULT_ADDR_WIDTH,
    parameter DATA_WIDTH   = `DEFAULT_DATA_WIDTH,
    parameter BLOCK_SIZE   = `DEFAULT_BLOCK_SIZE,
    parameter NUM_LINES    = `DEFAULT_NUM_LINES,
    parameter OFFSET_WIDTH = `DEFAULT_OFFSET_WIDTH,
    parameter INDEX_WIDTH  = `DEFAULT_INDEX_WIDTH,
    parameter TAG_WIDTH    = `DEFAULT_TAG_WIDTH,
    parameter BLOCK_BITS   = BLOCK_SIZE * DATA_WIDTH,
    parameter WRITE_POLICY = `POLICY_WRITE_BACK  // 1: Write-Back, 0: Write-Through
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // ------------------------------------------------------------------------
    // CPU Interface
    // ------------------------------------------------------------------------
    input  wire                    cpu_req,          // CPU access strobe
    input  wire                    cpu_rw,           // 0: Read, 1: Write
    input  wire [ADDR_WIDTH-1:0]   cpu_addr,         // Physical address
    input  wire [DATA_WIDTH-1:0]   cpu_wdata,        // CPU write data
    output wire [DATA_WIDTH-1:0]   cpu_rdata,        // CPU read data
    output wire                    cpu_ready,        // Ready / Acknowledge pulse
    output wire                    cpu_hit,          // Hit status (1: Hit, 0: Miss)
    output wire                    cpu_miss,         // Miss status

    // ------------------------------------------------------------------------
    // Main Memory Interface
    // ------------------------------------------------------------------------
    output wire                    mem_req,          // Memory request strobe
    output wire                    mem_rw,           // 0: Read Block, 1: Write
    output wire [ADDR_WIDTH-1:0]   mem_addr,         // Memory block address
    output wire [BLOCK_BITS-1:0]   mem_wdata_block,  // 32-bit block for write-back
    output wire [DATA_WIDTH-1:0]   mem_wdata_byte,   // 8-bit byte for write-through
    input  wire [BLOCK_BITS-1:0]   mem_rdata_block,  // 32-bit block read from mem
    input  wire                    mem_ready,        // Memory ready acknowledge

    // ------------------------------------------------------------------------
    // Performance Monitoring Unit (PMU) Outputs
    // ------------------------------------------------------------------------
    output wire [31:0]             perf_read_hits,
    output wire [31:0]             perf_read_misses,
    output wire [31:0]             perf_write_hits,
    output wire [31:0]             perf_write_misses,
    output wire [31:0]             perf_evictions,
    output wire [31:0]             perf_cycles
);

    // ------------------------------------------------------------------------
    // Internal Controller <-> Cache Memory Interconnect Wires
    // ------------------------------------------------------------------------
    wire [INDEX_WIDTH-1:0]  cache_r_index;
    wire [OFFSET_WIDTH-1:0] cache_r_offset;
    wire                    cache_r_valid;
    wire                    cache_r_dirty;
    wire [TAG_WIDTH-1:0]    cache_r_tag;
    wire [DATA_WIDTH-1:0]   cache_r_data;
    wire [BLOCK_BITS-1:0]   cache_r_block;

    wire                    cache_we_block;
    wire [INDEX_WIDTH-1:0]  cache_w_block_index;
    wire [TAG_WIDTH-1:0]    cache_w_block_tag;
    wire [BLOCK_BITS-1:0]   cache_w_block_data;
    wire                    cache_w_block_dirty;

    wire                    cache_we_byte;
    wire [INDEX_WIDTH-1:0]  cache_w_byte_index;
    wire [OFFSET_WIDTH-1:0] cache_w_byte_offset;
    wire [DATA_WIDTH-1:0]   cache_w_byte_data;

    wire                    cache_we_dirty;
    wire [INDEX_WIDTH-1:0]  cache_w_dirty_index;
    wire                    cache_w_dirty_val;

    // ------------------------------------------------------------------------
    // Cache Memory Storage Instance
    // ------------------------------------------------------------------------
    cache_memory_v2 #(
        .ADDR_WIDTH   (ADDR_WIDTH),
        .DATA_WIDTH   (DATA_WIDTH),
        .BLOCK_SIZE   (BLOCK_SIZE),
        .NUM_LINES    (NUM_LINES),
        .OFFSET_WIDTH (OFFSET_WIDTH),
        .INDEX_WIDTH  (INDEX_WIDTH),
        .TAG_WIDTH    (TAG_WIDTH)
    ) u_cache_memory_v2 (
        .clk           (clk),
        .rst_n         (rst_n),
        .r_index       (cache_r_index),
        .r_offset      (cache_r_offset),
        .r_valid       (cache_r_valid),
        .r_dirty       (cache_r_dirty),
        .r_tag         (cache_r_tag),
        .r_data        (cache_r_data),
        .r_block       (cache_r_block),
        .we_block      (cache_we_block),
        .w_block_index (cache_w_block_index),
        .w_block_tag   (cache_w_block_tag),
        .w_block_data  (cache_w_block_data),
        .w_block_dirty (cache_w_block_dirty),
        .we_byte       (cache_we_byte),
        .w_byte_index  (cache_w_byte_index),
        .w_byte_offset (cache_w_byte_offset),
        .w_byte_data   (cache_w_byte_data),
        .we_dirty      (cache_we_dirty),
        .w_dirty_index (cache_w_dirty_index),
        .w_dirty_val   (cache_w_dirty_val)
    );

    // ------------------------------------------------------------------------
    // Cache Controller FSM Instance
    // ------------------------------------------------------------------------
    cache_controller_v2 #(
        .ADDR_WIDTH   (ADDR_WIDTH),
        .DATA_WIDTH   (DATA_WIDTH),
        .BLOCK_SIZE   (BLOCK_SIZE),
        .NUM_LINES    (NUM_LINES),
        .OFFSET_WIDTH (OFFSET_WIDTH),
        .INDEX_WIDTH  (INDEX_WIDTH),
        .TAG_WIDTH    (TAG_WIDTH),
        .WRITE_POLICY (WRITE_POLICY)
    ) u_cache_controller_v2 (
        .clk                 (clk),
        .rst_n               (rst_n),
        .cpu_req             (cpu_req),
        .cpu_rw              (cpu_rw),
        .cpu_addr            (cpu_addr),
        .cpu_wdata           (cpu_wdata),
        .cpu_rdata           (cpu_rdata),
        .cpu_ready           (cpu_ready),
        .cpu_hit             (cpu_hit),
        .cpu_miss            (cpu_miss),
        .cache_r_index       (cache_r_index),
        .cache_r_offset      (cache_r_offset),
        .cache_r_valid       (cache_r_valid),
        .cache_r_dirty       (cache_r_dirty),
        .cache_r_tag         (cache_r_tag),
        .cache_r_data        (cache_r_data),
        .cache_r_block       (cache_r_block),
        .cache_we_block      (cache_we_block),
        .cache_w_block_index (cache_w_block_index),
        .cache_w_block_tag   (cache_w_block_tag),
        .cache_w_block_data  (cache_w_block_data),
        .cache_w_block_dirty (cache_w_block_dirty),
        .cache_we_byte       (cache_we_byte),
        .cache_w_byte_index  (cache_w_byte_index),
        .cache_w_byte_offset (cache_w_byte_offset),
        .cache_w_byte_data   (cache_w_byte_data),
        .cache_we_dirty      (cache_we_dirty),
        .cache_w_dirty_index (cache_w_dirty_index),
        .cache_w_dirty_val   (cache_w_dirty_val),
        .mem_req             (mem_req),
        .mem_rw              (mem_rw),
        .mem_addr            (mem_addr),
        .mem_wdata_block     (mem_wdata_block),
        .mem_wdata_byte      (mem_wdata_byte),
        .mem_rdata_block     (mem_rdata_block),
        .mem_ready           (mem_ready),
        .perf_read_hits      (perf_read_hits),
        .perf_read_misses    (perf_read_misses),
        .perf_write_hits     (perf_write_hits),
        .perf_write_misses   (perf_write_misses),
        .perf_evictions      (perf_evictions),
        .perf_cycles         (perf_cycles)
    );

endmodule

