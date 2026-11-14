// ============================================================================
// File: cache_data_array.v
// Project: Direct-Mapped Cache Controller (MCA Project)
// Module: Cache Data Array (SRAM storage for cache blocks)
// Description: Stores 256 cache lines of 128 bits (4 words) each.
//              Supports full-line read/write (for memory refills/evictions)
//              and individual word read/write (for CPU transactions).
// ============================================================================

`timescale 1ns / 1ps
`include "cache_defines.vh"

module cache_data_array (
    input  wire                           clk,
    input  wire                           rst_n,

    // Read interface
    input  wire [`INDEX_WIDTH-1:0]        r_index,
    input  wire [`WORD_OFFSET_WIDTH-1:0]  r_word_offset,
    output wire [`LINE_WIDTH-1:0]         r_line,
    output reg  [`DATA_WIDTH-1:0]         r_word,

    // Line-level write interface (Mem Refill)
    input  wire                           we_line,
    input  wire [`INDEX_WIDTH-1:0]        w_line_index,
    input  wire [`LINE_WIDTH-1:0]         w_line_data,

    // Word-level write interface (CPU Write)
    input  wire                           we_word,
    input  wire [`INDEX_WIDTH-1:0]        w_word_index,
    input  wire [`WORD_OFFSET_WIDTH-1:0]  w_word_offset,
    input  wire [`DATA_WIDTH-1:0]         w_word_data
);

    // 256 lines x 128 bits internal data memory
    reg [`LINE_WIDTH-1:0] data_mem [0:`NUM_LINES-1];

    integer i;

    // Asynchronous read for entire line
    assign r_line = data_mem[r_index];

    // Word extraction multiplexer for CPU read
    always @(*) begin
        case (r_word_offset)
            2'b00:   r_word = r_line[31:0];
            2'b01:   r_word = r_line[63:32];
            2'b10:   r_word = r_line[95:64];
            2'b11:   r_word = r_line[127:96];
            default: r_word = 32'h00000000;
        endcase
    end

    // Synchronous write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < `NUM_LINES; i = i + 1) begin
                data_mem[i] <= {`LINE_WIDTH{1'b0}};
            end
        end else begin
            if (we_line) begin
                // Full 128-bit block allocation from main memory
                data_mem[w_line_index] <= w_line_data;
            end else if (we_word) begin
                // Sub-block word write from CPU
                case (w_word_offset)
                    2'b00: data_mem[w_word_index][31:0]   <= w_word_data;
                    2'b01: data_mem[w_word_index][63:32]  <= w_word_data;
                    2'b10: data_mem[w_word_index][95:64]  <= w_word_data;
                    2'b11: data_mem[w_word_index][127:96] <= w_word_data;
                endcase
            end
        end
    end

endmodule

