// ============================================================================
// File: cache_memory_v2.v
// Project: Direct-Mapped Cache Controller (Phase II Enhancement)
// Role: Member 1 - Architecture & Cache Controller
// Description: Enhanced parameterizable cache memory array supporting:
//              - Parameterized address, line count, block size, and tag widths
//              - Valid bit array
//              - Dirty bit array (for Write-Back optimization)
//              - Asynchronous read port for fast tag & data lookup
//              - Synchronous line refill and sub-word write ports
// Standard: Verilog-2001 (IEEE 1364-2001)
// ============================================================================

`timescale 1ns / 1ps
`include "cache_defines_v2.vh"

module cache_memory_v2 #(
    parameter ADDR_WIDTH   = 16,
    parameter DATA_WIDTH   = 8,
    parameter BLOCK_SIZE   = 4,
    parameter NUM_LINES    = 4,
    parameter OFFSET_WIDTH = 2,
    parameter INDEX_WIDTH  = 2,
    parameter TAG_WIDTH    = 12,
    parameter BLOCK_BITS   = BLOCK_SIZE * DATA_WIDTH
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // ------------------------------------------------------------------------
    // Read Port (Asynchronous for zero-wait tag comparison and data forwarding)
    // ------------------------------------------------------------------------
    input  wire [INDEX_WIDTH-1:0]  r_index,
    input  wire [OFFSET_WIDTH-1:0] r_offset,
    output wire                    r_valid,
    output wire                    r_dirty,
    output wire [TAG_WIDTH-1:0]    r_tag,
    output wire [DATA_WIDTH-1:0]   r_data,
    output wire [BLOCK_BITS-1:0]   r_block,

    // ------------------------------------------------------------------------
    // Full Block Write / Refill Port (from Main Memory)
    // ------------------------------------------------------------------------
    input  wire                    we_block,
    input  wire [INDEX_WIDTH-1:0]  w_block_index,
    input  wire [TAG_WIDTH-1:0]    w_block_tag,
    input  wire [BLOCK_BITS-1:0]   w_block_data,
    input  wire                    w_block_dirty,

    // ------------------------------------------------------------------------
    // Single Byte/Word Write Port (from CPU Store operations)
    // ------------------------------------------------------------------------
    input  wire                    we_byte,
    input  wire [INDEX_WIDTH-1:0]  w_byte_index,
    input  wire [OFFSET_WIDTH-1:0] w_byte_offset,
    input  wire [DATA_WIDTH-1:0]   w_byte_data,

    // ------------------------------------------------------------------------
    // Dedicated Dirty-Bit Update Port
    // ------------------------------------------------------------------------
    input  wire                    we_dirty,
    input  wire [INDEX_WIDTH-1:0]  w_dirty_index,
    input  wire                    w_dirty_val
);

    // ------------------------------------------------------------------------
    // Internal Storage Arrays
    // ------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] data_array  [0:NUM_LINES-1][0:BLOCK_SIZE-1];
    reg [TAG_WIDTH-1:0]  tag_array   [0:NUM_LINES-1];
    reg [NUM_LINES-1:0]  valid_array;
    reg [NUM_LINES-1:0]  dirty_array;

    integer line_i, byte_i;

    // ------------------------------------------------------------------------
    // Synchronous Reset and Write Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_array <= {NUM_LINES{1'b0}};
            dirty_array <= {NUM_LINES{1'b0}};
            for (line_i = 0; line_i < NUM_LINES; line_i = line_i + 1) begin
                tag_array[line_i] <= {TAG_WIDTH{1'b0}};
                for (byte_i = 0; byte_i < BLOCK_SIZE; byte_i = byte_i + 1) begin
                    data_array[line_i][byte_i] <= {DATA_WIDTH{1'b0}};
                end
            end
        end else begin
            // 1. Block-level allocation/refill
            if (we_block) begin
                tag_array[w_block_index]   <= w_block_tag;
                valid_array[w_block_index] <= 1'b1;
                dirty_array[w_block_index] <= w_block_dirty;

                // Load all bytes into line
                data_array[w_block_index][0] <= w_block_data[7:0];
                data_array[w_block_index][1] <= w_block_data[15:8];
                data_array[w_block_index][2] <= w_block_data[23:16];
                data_array[w_block_index][3] <= w_block_data[31:24];
            end

            // 2. Sub-block byte/word update (CPU write)
            if (we_byte) begin
                data_array[w_byte_index][w_byte_offset] <= w_byte_data;
            end

            // 3. Explicit dirty bit update
            if (we_dirty) begin
                dirty_array[w_dirty_index] <= w_dirty_val;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Asynchronous / Combinational Read Routing
    // ------------------------------------------------------------------------
    assign r_valid = valid_array[r_index];
    assign r_dirty = dirty_array[r_index];
    assign r_tag   = tag_array[r_index];
    assign r_data  = data_array[r_index][r_offset];
    assign r_block = {data_array[r_index][3],
                      data_array[r_index][2],
                      data_array[r_index][1],
                      data_array[r_index][0]};

endmodule

