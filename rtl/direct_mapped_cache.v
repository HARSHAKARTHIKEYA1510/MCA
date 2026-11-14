// ============================================================================
// File: direct_mapped_cache.v
// Project: 16-Bit Direct-Mapped Cache Controller Using Verilog HDL
// Description: Top-Level Module integrating:
//              1. cache_controller: 6-state FSM and Handshake coordinator
//              2. cache_memory: 4-line x 4-byte SRAM with Tag and Valid storage
// Standard: Verilog-2001 (IEEE 1364-2001)
// ============================================================================

`timescale 1ns / 1ps

module direct_mapped_cache (
    input  wire        clk,
    input  wire        rst_n,

    // ------------------------------------------------------------------------
    // CPU Interface
    // ------------------------------------------------------------------------
    input  wire        cpu_req,          // CPU access strobe
    input  wire        cpu_rw,           // 0: Read, 1: Write
    input  wire [15:0] cpu_addr,         // 16-bit physical address
    input  wire [7:0]  cpu_wdata,        // 8-bit write data byte
    output wire [7:0]  cpu_rdata,        // 8-bit read data byte
    output wire        cpu_ready,        // Ready / Acknowledge pulse (1 cycle)
    output wire        cpu_hit,          // Hit status (1: Hit, 0: Miss)

    // ------------------------------------------------------------------------
    // Main Memory Bus Interface
    // ------------------------------------------------------------------------
    output wire        mem_req,          // Memory operation strobe
    output wire        mem_rw,           // 0: Read 4-Byte Block, 1: Write Single Byte
    output wire [15:0] mem_addr,         // 16-bit block/byte address
    output wire [7:0]  mem_wdata,        // 8-bit write data byte
    input  wire [31:0] mem_rdata_block,  // 32-bit (4-byte) block returned from memory
    input  wire        mem_ready         // Memory completion acknowledge
);

    // ------------------------------------------------------------------------
    // Internal Interconnect Signals (Controller <-> Cache Memory)
    // ------------------------------------------------------------------------
    wire [1:0]  cache_r_index;
    wire [1:0]  cache_r_offset;
    wire        cache_r_valid;
    wire [11:0] cache_r_tag;
    wire [7:0]  cache_r_byte;
    wire [31:0] cache_r_block;

    wire        cache_we_block;
    wire [1:0]  cache_w_block_index;
    wire [11:0] cache_w_block_tag;
    wire [31:0] cache_w_block_data;

    wire        cache_we_byte;
    wire [1:0]  cache_w_byte_index;
    wire [1:0]  cache_w_byte_offset;
    wire [7:0]  cache_w_byte_data;

    // ------------------------------------------------------------------------
    // Cache Memory Storage Instance
    // ------------------------------------------------------------------------
    cache_memory u_cache_memory (
        .clk           (clk),
        .rst_n         (rst_n),
        .r_index       (cache_r_index),
        .r_offset      (cache_r_offset),
        .r_valid       (cache_r_valid),
        .r_tag         (cache_r_tag),
        .r_byte        (cache_r_byte),
        .r_block       (cache_r_block),
        .we_block      (cache_we_block),
        .w_block_index (cache_w_block_index),
        .w_block_tag   (cache_w_block_tag),
        .w_block_data  (cache_w_block_data),
        .we_byte       (cache_we_byte),
        .w_byte_index  (cache_w_byte_index),
        .w_byte_offset (cache_w_byte_offset),
        .w_byte_data   (cache_w_byte_data)
    );

    // ------------------------------------------------------------------------
    // Cache Controller FSM Instance
    // ------------------------------------------------------------------------
    cache_controller u_cache_controller (
        .clk                 (clk),
        .rst_n               (rst_n),
        .cpu_req             (cpu_req),
        .cpu_rw              (cpu_rw),
        .cpu_addr            (cpu_addr),
        .cpu_wdata           (cpu_wdata),
        .cpu_rdata           (cpu_rdata),
        .cpu_ready           (cpu_ready),
        .cpu_hit             (cpu_hit),
        .cache_r_index       (cache_r_index),
        .cache_r_offset      (cache_r_offset),
        .cache_r_valid       (cache_r_valid),
        .cache_r_tag         (cache_r_tag),
        .cache_r_byte        (cache_r_byte),
        .cache_r_block       (cache_r_block),
        .cache_we_block      (cache_we_block),
        .cache_w_block_index (cache_w_block_index),
        .cache_w_block_tag   (cache_w_block_tag),
        .cache_w_block_data  (cache_w_block_data),
        .cache_we_byte       (cache_we_byte),
        .cache_w_byte_index  (cache_w_byte_index),
        .cache_w_byte_offset (cache_w_byte_offset),
        .cache_w_byte_data   (cache_w_byte_data),
        .mem_req             (mem_req),
        .mem_rw              (mem_rw),
        .mem_addr            (mem_addr),
        .mem_wdata           (mem_wdata),
        .mem_rdata_block     (mem_rdata_block),
        .mem_ready           (mem_ready)
    );

endmodule
