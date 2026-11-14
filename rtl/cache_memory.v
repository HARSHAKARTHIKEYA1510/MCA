// ============================================================================
// File: cache_memory.v
// Project: 16-Bit Direct-Mapped Cache Controller Using Verilog HDL
// Description: Implements 4 cache lines, 4 bytes per line (16 bytes total),
//              12-bit tag per line, and 1 valid bit per line.
// Standard: Verilog-2001 (IEEE 1364-2001)
// ============================================================================

`timescale 1ns / 1ps

module cache_memory (
    input  wire        clk,
    input  wire        rst_n,

    // ------------------------------------------------------------------------
    // Read Port (Asynchronous lookup for fast tag comparison & data retrieval)
    // ------------------------------------------------------------------------
    input  wire [1:0]  r_index,          // 2-bit Line Index (Lines 0..3)
    input  wire [1:0]  r_offset,         // 2-bit Byte Offset (Bytes 0..3)
    output wire        r_valid,          // Valid bit of indexed line
    output wire [11:0] r_tag,            // Stored 12-bit Tag of indexed line
    output wire [7:0]  r_byte,           // 8-bit data byte at (r_index, r_offset)
    output wire [31:0] r_block,          // 32-bit (4-byte) block at r_index

    // ------------------------------------------------------------------------
    // Write Block Port (Used during Line Allocation / Refill)
    // ------------------------------------------------------------------------
    input  wire        we_block,         // Block write enable
    input  wire [1:0]  w_block_index,    // Target line index
    input  wire [11:0] w_block_tag,      // 12-bit tag to store
    input  wire [31:0] w_block_data,     // 32-bit block data {Byte3, Byte2, Byte1, Byte0}

    // ------------------------------------------------------------------------
    // Write Byte Port (Used during CPU Write Hit & Write-Allocate Byte Update)
    // ------------------------------------------------------------------------
    input  wire        we_byte,          // Single-byte write enable
    input  wire [1:0]  w_byte_index,     // Target line index
    input  wire [1:0]  w_byte_offset,    // Target byte offset (0..3)
    input  wire [7:0]  w_byte_data       // 8-bit data byte to write
);

    // ------------------------------------------------------------------------
    // Storage Elements
    // - 4 Cache lines
    // - 4 Bytes per line
    // - 12-bit Tag per line
    // - 1 Valid bit per line
    // ------------------------------------------------------------------------
    reg [7:0]  data_array [0:3][0:3];    // [Line Index 0..3][Byte Offset 0..3]
    reg [11:0] tag_array  [0:3];         // 12-bit Tag per line
    reg [3:0]  valid_array;              // Valid bit vector for 4 lines

    integer line_idx;
    integer byte_idx;

    // ------------------------------------------------------------------------
    // Synchronous Write Logic with Active-Low Reset
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_array <= 4'b0000;
            for (line_idx = 0; line_idx < 4; line_idx = line_idx + 1) begin
                tag_array[line_idx] <= 12'h000;
                for (byte_idx = 0; byte_idx < 4; byte_idx = byte_idx + 1) begin
                    data_array[line_idx][byte_idx] <= 8'h00;
                end
            end
        end else begin
            // 1. Full block write (Line Allocation on Miss)
            if (we_block) begin
                tag_array[w_block_index]        <= w_block_tag;
                valid_array[w_block_index]      <= 1'b1;
                data_array[w_block_index][0]    <= w_block_data[7:0];
                data_array[w_block_index][1]    <= w_block_data[15:8];
                data_array[w_block_index][2]    <= w_block_data[23:16];
                data_array[w_block_index][3]    <= w_block_data[31:24];
            end

            // 2. Single byte write (Write Hit or post-allocation byte modification)
            if (we_byte) begin
                data_array[w_byte_index][w_byte_offset] <= w_byte_data;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Combinational Read Assignments
    // ------------------------------------------------------------------------
    assign r_valid = valid_array[r_index];
    assign r_tag   = tag_array[r_index];
    assign r_byte  = data_array[r_index][r_offset];
    assign r_block = {data_array[r_index][3],
                      data_array[r_index][2],
                      data_array[r_index][1],
                      data_array[r_index][0]};

endmodule
