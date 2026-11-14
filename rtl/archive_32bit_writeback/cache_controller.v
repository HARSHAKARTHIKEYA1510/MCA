// ============================================================================
// File: cache_controller.v
// Project: Direct-Mapped Cache Controller (MCA Project)
// Module: Top-Level Cache Controller & Datapath
// Description: Implements a 4 KB Direct-Mapped Cache with 16-byte lines,
//              Write-Back policy, Write-Allocate, and a 5-state FSM.
// ============================================================================

`timescale 1ns / 1ps
`include "cache_defines.vh"

module cache_controller (
    input  wire                           clk,
    input  wire                           rst_n,

    // ------------------------------------------------------------------------
    // CPU Interface
    // ------------------------------------------------------------------------
    input  wire                           cpu_req,      // CPU memory request
    input  wire [`ADDR_WIDTH-1:0]         cpu_addr,     // CPU address
    input  wire                           cpu_rw,       // 0: Read, 1: Write
    input  wire [`DATA_WIDTH-1:0]         cpu_wdata,    // CPU write data
    output reg  [`DATA_WIDTH-1:0]         cpu_rdata,    // CPU read data
    output reg                            cpu_ready,    // Acknowledge / Ready pulse
    output reg                            cpu_hit,      // Status: 1 = Hit, 0 = Miss

    // ------------------------------------------------------------------------
    // Main Memory Interface
    // ------------------------------------------------------------------------
    output reg                            mem_req,      // Main memory request
    output reg  [`ADDR_WIDTH-1:0]         mem_addr,     // Main memory block address
    output reg                            mem_rw,       // 0: Read block, 1: Write block
    output wire [`LINE_WIDTH-1:0]         mem_wdata,    // Block data to write back
    input  wire [`LINE_WIDTH-1:0]         mem_rdata,    // Block data read from memory
    input  wire                           mem_ready     // Memory completion acknowledge
);

    // ------------------------------------------------------------------------
    // Latched CPU Request Registers
    // ------------------------------------------------------------------------
    reg [`ADDR_WIDTH-1:0]         latched_addr;
    reg                           latched_rw;
    reg [`DATA_WIDTH-1:0]         latched_wdata;
    reg [`TAG_WIDTH-1:0]          latched_evict_tag;

    // Sliced address fields from latched address
    wire [`TAG_WIDTH-1:0]         req_tag         = latched_addr[`ADDR_TAG];
    wire [`INDEX_WIDTH-1:0]       req_index       = latched_addr[`ADDR_INDEX];
    wire [`WORD_OFFSET_WIDTH-1:0] req_word_offset = latched_addr[`ADDR_WORD_OFFSET];

    // Current address fields (used in IDLE for immediate indexing)
    wire [`INDEX_WIDTH-1:0]       curr_index       = cpu_addr[`ADDR_INDEX];
    wire [`WORD_OFFSET_WIDTH-1:0] curr_word_offset = cpu_addr[`ADDR_WORD_OFFSET];

    // Effective index multiplexer (active transaction vs incoming)
    wire [`INDEX_WIDTH-1:0]       active_index       = (state == `S_IDLE) ? curr_index : req_index;
    wire [`WORD_OFFSET_WIDTH-1:0] active_word_offset = (state == `S_IDLE) ? curr_word_offset : req_word_offset;

    // ------------------------------------------------------------------------
    // FSM State Registers
    // ------------------------------------------------------------------------
    reg [`STATE_WIDTH-1:0] state;
    reg [`STATE_WIDTH-1:0] next_state;

    // ------------------------------------------------------------------------
    // Tag Array Interface Signals
    // ------------------------------------------------------------------------
    wire [`TAG_WIDTH-1:0]   stored_tag;
    wire                    stored_valid;
    wire                    stored_dirty;

    reg                     tag_we_tag;
    reg                     tag_we_valid;
    reg                     tag_we_dirty;
    reg  [`TAG_WIDTH-1:0]   tag_w_tag;
    reg                     tag_w_valid;
    reg                     tag_w_dirty;

    // ------------------------------------------------------------------------
    // Data Array Interface Signals
    // ------------------------------------------------------------------------
    wire [`LINE_WIDTH-1:0]  data_r_line;
    wire [`DATA_WIDTH-1:0]  data_r_word;

    reg                     data_we_line;
    reg  [`LINE_WIDTH-1:0]  data_w_line;
    reg                     data_we_word;
    reg  [`DATA_WIDTH-1:0]  data_w_word;

    // Memory write data connects directly to current cache line
    assign mem_wdata = data_r_line;

    // ------------------------------------------------------------------------
    // Hit / Miss Logic
    // ------------------------------------------------------------------------
    wire tag_match = (stored_tag == req_tag);
    wire is_hit    = stored_valid && tag_match;

    // ------------------------------------------------------------------------
    // Sub-Module Instantiations
    // ------------------------------------------------------------------------
    cache_tag_array u_tag_array (
        .clk      (clk),
        .rst_n    (rst_n),
        .r_index  (active_index),
        .r_tag    (stored_tag),
        .r_valid  (stored_valid),
        .r_dirty  (stored_dirty),
        .we_tag   (tag_we_tag),
        .we_valid (tag_we_valid),
        .we_dirty (tag_we_dirty),
        .w_index  (req_index),
        .w_tag    (tag_w_tag),
        .w_valid  (tag_w_valid),
        .w_dirty  (tag_w_dirty)
    );

    cache_data_array u_data_array (
        .clk           (clk),
        .rst_n         (rst_n),
        .r_index       (active_index),
        .r_word_offset (active_word_offset),
        .r_line        (data_r_line),
        .r_word        (data_r_word),
        .we_line       (data_we_line),
        .w_line_index  (req_index),
        .w_line_data   (data_w_line),
        .we_word       (data_we_word),
        .w_word_index  (req_index),
        .w_word_offset (req_word_offset),
        .w_word_data   (data_w_word)
    );

    // ------------------------------------------------------------------------
    // FSM State Register & Input Latching
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= `S_IDLE;
            latched_addr      <= {`ADDR_WIDTH{1'b0}};
            latched_rw        <= `OP_READ;
            latched_wdata     <= {`DATA_WIDTH{1'b0}};
            latched_evict_tag <= {`TAG_WIDTH{1'b0}};
        end else begin
            state <= next_state;

            // Latch CPU inputs when a new request is detected in IDLE
            if (state == `S_IDLE && cpu_req) begin
                latched_addr  <= cpu_addr;
                latched_rw    <= cpu_rw;
                latched_wdata <= cpu_wdata;
            end

            // Capture eviction tag when miss is identified in COMPARE_TAG
            if (state == `S_COMPARE_TAG && !is_hit) begin
                latched_evict_tag <= stored_tag;
            end
        end
    end

    // ------------------------------------------------------------------------
    // FSM Next-State Logic (Combinational)
    // ------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            `S_IDLE: begin
                if (cpu_req) begin
                    next_state = `S_COMPARE_TAG;
                end
            end

            `S_COMPARE_TAG: begin
                if (is_hit) begin
                    // Cache Hit: transaction completes immediately
                    next_state = `S_IDLE;
                end else begin
                    // Cache Miss
                    if (stored_valid && stored_dirty) begin
                        // Dirty line must be evicted first
                        next_state = `S_WRITE_BACK;
                    end else begin
                        // Clean or Invalid line: directly allocate
                        next_state = `S_ALLOCATE;
                    end
                end
            end

            `S_WRITE_BACK: begin
                // Wait for memory to acknowledge writeback
                if (mem_ready) begin
                    next_state = `S_ALLOCATE;
                end
            end

            `S_ALLOCATE: begin
                // Wait for memory to supply the requested 128-bit line
                if (mem_ready) begin
                    next_state = `S_UPDATE;
                end
            end

            `S_UPDATE: begin
                // Updates are committed in this cycle, return to IDLE
                next_state = `S_IDLE;
            end

            default: next_state = `S_IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // FSM Output & Datapath Control Logic
    // ------------------------------------------------------------------------
    always @(*) begin
        // Defaults
        cpu_ready     = 1'b0;
        cpu_hit       = 1'b0;
        cpu_rdata     = {`DATA_WIDTH{1'b0}};

        mem_req       = 1'b0;
        mem_addr      = {`ADDR_WIDTH{1'b0}};
        mem_rw        = `OP_READ;

        tag_we_tag    = 1'b0;
        tag_we_valid  = 1'b0;
        tag_we_dirty  = 1'b0;
        tag_w_tag     = req_tag;
        tag_w_valid   = 1'b1;
        tag_w_dirty   = 1'b0;

        data_we_line  = 1'b0;
        data_w_line   = mem_rdata;
        data_we_word  = 1'b0;
        data_w_word   = latched_wdata;

        case (state)
            `S_IDLE: begin
                // Idle state, outputs deasserted
            end

            `S_COMPARE_TAG: begin
                if (is_hit) begin
                    cpu_hit   = 1'b1;
                    cpu_ready = 1'b1;

                    if (latched_rw == `OP_READ) begin
                        cpu_rdata = data_r_word;
                    end else begin
                        // Hit on write: modify designated word and set dirty
                        data_we_word = 1'b1;
                        data_w_word  = latched_wdata;
                        tag_we_dirty = 1'b1;
                        tag_w_dirty  = 1'b1;
                    end
                end else begin
                    cpu_hit = 1'b0;
                end
            end

            `S_WRITE_BACK: begin
                // Evict dirty line to main memory at {latched_evict_tag, req_index, 4'b0000}
                mem_req  = 1'b1;
                mem_rw   = `OP_WRITE;
                mem_addr = {latched_evict_tag, req_index, 4'b0000};
            end

            `S_ALLOCATE: begin
                // Read 16-byte block from main memory at {req_tag, req_index, 4'b0000}
                mem_req  = 1'b1;
                mem_rw   = `OP_READ;
                mem_addr = {req_tag, req_index, 4'b0000};

                if (mem_ready) begin
                    // Store incoming memory block and update tag/valid
                    data_we_line = 1'b1;
                    data_w_line  = mem_rdata;
                    tag_we_tag   = 1'b1;
                    tag_w_tag    = req_tag;
                    tag_we_valid = 1'b1;
                    tag_w_valid  = 1'b1;
                end
            end

            `S_UPDATE: begin
                cpu_ready = 1'b1;
                cpu_hit   = 1'b0; // Was originally a miss

                if (latched_rw == `OP_READ) begin
                    // Read miss completion: data is now in cache data array
                    cpu_rdata    = data_r_word;
                    tag_we_dirty = 1'b1;
                    tag_w_dirty  = 1'b0; // Clean block
                end else begin
                    // Write miss completion (Write-Allocate): modify target word and set dirty
                    data_we_word = 1'b1;
                    data_w_word  = latched_wdata;
                    tag_we_dirty = 1'b1;
                    tag_w_dirty  = 1'b1; // Line is now modified
                end
            end

            default: ;
        endcase
    end

endmodule

