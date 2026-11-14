// ============================================================================
// File: cache_tag_array.v
// Project: Direct-Mapped Cache Controller (MCA Project)
// Module: Tag, Valid, and Dirty Bit Array Storage
// Description: Stores 256 entries of 20-bit Tags, Valid bits, and Dirty bits.
//              Provides synchronous read and selective update ports.
// ============================================================================

`timescale 1ns / 1ps
`include "cache_defines.vh"

module cache_tag_array (
    input  wire                     clk,
    input  wire                     rst_n,

    // Read interface
    input  wire [`INDEX_WIDTH-1:0]  r_index,
    output wire [`TAG_WIDTH-1:0]    r_tag,
    output wire                     r_valid,
    output wire                     r_dirty,

    // Write / Update interface
    input  wire                     we_tag,
    input  wire                     we_valid,
    input  wire                     we_dirty,
    input  wire [`INDEX_WIDTH-1:0]  w_index,
    input  wire [`TAG_WIDTH-1:0]    w_tag,
    input  wire                     w_valid,
    input  wire                     w_dirty
);

    // Internal storage arrays
    reg [`TAG_WIDTH-1:0] tag_mem   [0:`NUM_LINES-1];
    reg                  valid_mem [0:`NUM_LINES-1];
    reg                  dirty_mem [0:`NUM_LINES-1];

    integer i;

    // Asynchronous/Combinational read for immediate evaluation in state machine
    assign r_tag   = tag_mem[r_index];
    assign r_valid = valid_mem[r_index];
    assign r_dirty = dirty_mem[r_index];

    // Synchronous write & reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < `NUM_LINES; i = i + 1) begin
                tag_mem[i]   <= {`TAG_WIDTH{1'b0}};
                valid_mem[i] <= 1'b0;
                dirty_mem[i] <= 1'b0;
            end
        end else begin
            if (we_tag) begin
                tag_mem[w_index] <= w_tag;
            end
            if (we_valid) begin
                valid_mem[w_index] <= w_valid;
            end
            if (we_dirty) begin
                dirty_mem[w_index] <= w_dirty;
            end
        end
    end

endmodule

