// ============================================================================
// File: cache_controller_v2.v
// Project: Direct-Mapped Cache Controller (Phase II Enhancement)
// Role: Member 1 - Architecture & Cache Controller
// Description: Advanced, fully parameterized master FSM cache controller:
//              - Parameterized address, tag, index, and offset slicing
//              - Fast-path combinational hit/miss evaluation
//              - Selectable write policy (Write-Back w/ Dirty bit vs Write-Through)
//              - Single-cycle hit execution
//              - Integrated hardware performance monitoring unit (PMU)
// Standard: Verilog-2001 (IEEE 1364-2001)
// ============================================================================

`timescale 1ns / 1ps
`include "cache_defines_v2.vh"

module cache_controller_v2 #(
    parameter ADDR_WIDTH   = 16,
    parameter DATA_WIDTH   = 8,
    parameter BLOCK_SIZE   = 4,
    parameter NUM_LINES    = 4,
    parameter OFFSET_WIDTH = 2,
    parameter INDEX_WIDTH  = 2,
    parameter TAG_WIDTH    = 12,
    parameter BLOCK_BITS   = BLOCK_SIZE * DATA_WIDTH,
    parameter WRITE_POLICY = `POLICY_WRITE_BACK  // 1: Write-Back, 0: Write-Through
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // ------------------------------------------------------------------------
    // CPU Interface
    // ------------------------------------------------------------------------
    input  wire                    cpu_req,
    input  wire                    cpu_rw,          // 0: Read, 1: Write
    input  wire [ADDR_WIDTH-1:0]   cpu_addr,
    input  wire [DATA_WIDTH-1:0]   cpu_wdata,
    output reg  [DATA_WIDTH-1:0]   cpu_rdata,
    output reg                     cpu_ready,
    output reg                     cpu_hit,
    output reg                     cpu_miss,

    // ------------------------------------------------------------------------
    // Cache Memory Array Interface
    // ------------------------------------------------------------------------
    output wire [INDEX_WIDTH-1:0]  cache_r_index,
    output wire [OFFSET_WIDTH-1:0] cache_r_offset,
    input  wire                    cache_r_valid,
    input  wire                    cache_r_dirty,
    input  wire [TAG_WIDTH-1:0]    cache_r_tag,
    input  wire [DATA_WIDTH-1:0]   cache_r_data,
    input  wire [BLOCK_BITS-1:0]   cache_r_block,

    output reg                     cache_we_block,
    output reg  [INDEX_WIDTH-1:0]  cache_w_block_index,
    output reg  [TAG_WIDTH-1:0]    cache_w_block_tag,
    output reg  [BLOCK_BITS-1:0]   cache_w_block_data,
    output reg                     cache_w_block_dirty,

    output reg                     cache_we_byte,
    output reg  [INDEX_WIDTH-1:0]  cache_w_byte_index,
    output reg  [OFFSET_WIDTH-1:0] cache_w_byte_offset,
    output reg  [DATA_WIDTH-1:0]   cache_w_byte_data,

    output reg                     cache_we_dirty,
    output reg  [INDEX_WIDTH-1:0]  cache_w_dirty_index,
    output reg                     cache_w_dirty_val,

    // ------------------------------------------------------------------------
    // Main Memory Interface
    // ------------------------------------------------------------------------
    output reg                     mem_req,
    output reg                     mem_rw,          // 0: Read Block, 1: Write
    output reg  [ADDR_WIDTH-1:0]   mem_addr,
    output reg  [BLOCK_BITS-1:0]   mem_wdata_block,
    output reg  [DATA_WIDTH-1:0]   mem_wdata_byte,
    input  wire [BLOCK_BITS-1:0]   mem_rdata_block,
    input  wire                    mem_ready,

    // ------------------------------------------------------------------------
    // Hardware Performance Monitoring Unit (PMU) Counters
    // ------------------------------------------------------------------------
    output reg  [31:0]             perf_read_hits,
    output reg  [31:0]             perf_read_misses,
    output reg  [31:0]             perf_write_hits,
    output reg  [31:0]             perf_write_misses,
    output reg  [31:0]             perf_evictions,
    output reg  [31:0]             perf_cycles
);

    // ------------------------------------------------------------------------
    // FSM State Registers
    // ------------------------------------------------------------------------
    reg [2:0] state, next_state;

    // ------------------------------------------------------------------------
    // Latched Transaction Registers
    // ------------------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] latched_addr;
    reg                  latched_rw;
    reg [DATA_WIDTH-1:0] latched_wdata;
    reg [TAG_WIDTH-1:0]  latched_evict_tag;
    reg [BLOCK_BITS-1:0] latched_mem_block;
    reg                  latched_hit;
    reg [DATA_WIDTH-1:0] cpu_rdata_reg;

    // Sliced address fields
    wire [TAG_WIDTH-1:0]    req_tag    = latched_addr[ADDR_WIDTH-1 : ADDR_WIDTH-TAG_WIDTH];
    wire [INDEX_WIDTH-1:0]  req_index  = latched_addr[ADDR_WIDTH-TAG_WIDTH-1 : OFFSET_WIDTH];
    wire [OFFSET_WIDTH-1:0] req_offset = latched_addr[OFFSET_WIDTH-1 : 0];

    // Incoming address slicing for immediate lookup during IDLE
    wire [INDEX_WIDTH-1:0]  curr_index  = cpu_addr[ADDR_WIDTH-TAG_WIDTH-1 : OFFSET_WIDTH];
    wire [OFFSET_WIDTH-1:0] curr_offset = cpu_addr[OFFSET_WIDTH-1 : 0];

    // Read index and offset routing
    assign cache_r_index  = (state == `S_IDLE) ? curr_index  : req_index;
    assign cache_r_offset = (state == `S_IDLE) ? curr_offset : req_offset;

    // Fast-path Tag Comparison & Hit Detection Logic
    wire tag_match     = (cache_r_tag == req_tag);
    wire hit_condition = cache_r_valid && tag_match;

    // Sub-word byte selection function
    function [DATA_WIDTH-1:0] get_byte_from_block;
        input [BLOCK_BITS-1:0]   blk;
        input [OFFSET_WIDTH-1:0] off;
        begin
            case (off)
                2'b00:   get_byte_from_block = blk[7:0];
                2'b01:   get_byte_from_block = blk[15:8];
                2'b10:   get_byte_from_block = blk[23:16];
                2'b11:   get_byte_from_block = blk[31:24];
                default: get_byte_from_block = blk[7:0];
            endcase
        end
    endfunction

    // ------------------------------------------------------------------------
    // Synchronous FSM State Update & Datapath
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= `S_IDLE;
            latched_addr      <= {ADDR_WIDTH{1'b0}};
            latched_rw        <= 1'b0;
            latched_wdata     <= {DATA_WIDTH{1'b0}};
            latched_evict_tag <= {TAG_WIDTH{1'b0}};
            latched_mem_block <= {BLOCK_BITS{1'b0}};
            latched_hit       <= 1'b0;
            cpu_rdata_reg     <= {DATA_WIDTH{1'b0}};

            // Reset PMU Counters
            perf_read_hits    <= 32'd0;
            perf_read_misses  <= 32'd0;
            perf_write_hits   <= 32'd0;
            perf_write_misses <= 32'd0;
            perf_evictions    <= 32'd0;
            perf_cycles       <= 32'd0;
        end else begin
            state       <= next_state;
            perf_cycles <= perf_cycles + 1'b1;

            case (state)
                `S_IDLE: begin
                    if (cpu_req) begin
                        latched_addr  <= cpu_addr;
                        latched_rw    <= cpu_rw;
                        latched_wdata <= cpu_wdata;
                    end
                end

                `S_COMPARE_TAG: begin
                    latched_hit <= hit_condition;
                    if (hit_condition) begin
                        if (latched_rw == `OP_READ) begin
                            cpu_rdata_reg  <= cache_r_data;
                            perf_read_hits <= perf_read_hits + 1'b1;
                        end else begin
                            perf_write_hits <= perf_write_hits + 1'b1;
                        end
                    end else begin
                        // Cache Miss
                        if (latched_rw == `OP_READ) begin
                            perf_read_misses <= perf_read_misses + 1'b1;
                        end else begin
                            perf_write_misses <= perf_write_misses + 1'b1;
                        end

                        // If Write-Back policy and line is dirty, capture eviction tag
                        if ((WRITE_POLICY == `POLICY_WRITE_BACK) && cache_r_valid && cache_r_dirty) begin
                            latched_evict_tag <= cache_r_tag;
                            perf_evictions    <= perf_evictions + 1'b1;
                        end
                    end
                end

                `S_WRITE_BACK: begin
                    // Dirty line flushed to main memory
                end

                `S_ALLOCATE: begin
                    if (mem_ready) begin
                        latched_mem_block <= mem_rdata_block;
                        if (latched_rw == `OP_READ) begin
                            cpu_rdata_reg <= get_byte_from_block(mem_rdata_block, req_offset);
                        end
                    end
                end

                `S_UPDATE: begin
                    // Updates committed to cache SRAM
                end

                default: ;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Next-State Combinational Logic
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
                if (hit_condition) begin
                    if (latched_rw == `OP_READ) begin
                        // Single-cycle Read Hit
                        next_state = `S_IDLE;
                    end else begin
                        // Write Hit
                        if (WRITE_POLICY == `POLICY_WRITE_BACK) begin
                            // Fast 1-cycle Write Hit in cache (marked dirty)
                            next_state = `S_IDLE;
                        end else begin
                            // Write-Through: must write through to main memory
                            next_state = `S_UPDATE;
                        end
                    end
                end else begin
                    // Cache Miss
                    if ((WRITE_POLICY == `POLICY_WRITE_BACK) && cache_r_valid && cache_r_dirty) begin
                        next_state = `S_WRITE_BACK;
                    end else begin
                        next_state = `S_ALLOCATE;
                    end
                end
            end

            `S_WRITE_BACK: begin
                if (mem_ready) begin
                    next_state = `S_ALLOCATE;
                end
            end

            `S_ALLOCATE: begin
                if (mem_ready) begin
                    next_state = `S_UPDATE;
                end
            end

            `S_UPDATE: begin
                if (WRITE_POLICY == `POLICY_WRITE_THROUGH && latched_rw == `OP_WRITE) begin
                    if (mem_ready) begin
                        next_state = `S_IDLE;
                    end
                end else begin
                    next_state = `S_IDLE;
                end
            end

            default: next_state = `S_IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // Datapath & Output Combinational Logic
    // ------------------------------------------------------------------------
    always @(*) begin
        // Default CPU outputs
        cpu_ready           = 1'b0;
        cpu_hit             = 1'b0;
        cpu_miss            = 1'b0;
        cpu_rdata           = cpu_rdata_reg;

        // Default Cache Memory controls
        cache_we_block      = 1'b0;
        cache_w_block_index = req_index;
        cache_w_block_tag   = req_tag;
        cache_w_block_data  = latched_mem_block;
        cache_w_block_dirty = 1'b0;

        cache_we_byte       = 1'b0;
        cache_w_byte_index  = req_index;
        cache_w_byte_offset = req_offset;
        cache_w_byte_data   = latched_wdata;

        cache_we_dirty      = 1'b0;
        cache_w_dirty_index = req_index;
        cache_w_dirty_val   = 1'b0;

        // Default Main Memory controls
        mem_req             = 1'b0;
        mem_rw              = 1'b0;
        mem_addr            = {ADDR_WIDTH{1'b0}};
        mem_wdata_block     = cache_r_block;
        mem_wdata_byte      = latched_wdata;

        case (state)
            `S_IDLE: begin
                // Dormant
            end

            `S_COMPARE_TAG: begin
                if (hit_condition) begin
                    cpu_hit   = 1'b1;
                    cpu_miss  = 1'b0;

                    if (latched_rw == `OP_READ) begin
                        // Instant read hit completion
                        cpu_ready = 1'b1;
                        cpu_rdata = cache_r_data;
                    end else begin
                        // Write Hit: update byte in cache line
                        cache_we_byte = 1'b1;
                        if (WRITE_POLICY == `POLICY_WRITE_BACK) begin
                            // Fast Write Hit: set dirty bit, acknowledge CPU
                            cache_we_dirty    = 1'b1;
                            cache_w_dirty_val = 1'b1;
                            cpu_ready         = 1'b1;
                        end else begin
                            // Write-Through: initiate memory write
                            mem_req   = 1'b1;
                            mem_rw    = 1'b1;
                            mem_addr  = latched_addr;
                        end
                    end
                end else begin
                    cpu_hit  = 1'b0;
                    cpu_miss = 1'b1;
                end
            end

            `S_WRITE_BACK: begin
                // Write 4-byte dirty block to memory at {latched_evict_tag, req_index, 2'b00}
                mem_req         = 1'b1;
                mem_rw          = 1'b1; // Block write
                mem_addr        = {latched_evict_tag, req_index, {OFFSET_WIDTH{1'b0}}};
                mem_wdata_block = cache_r_block;
            end

            `S_ALLOCATE: begin
                // Read 4-byte block from memory at {req_tag, req_index, 2'b00}
                mem_req  = 1'b1;
                mem_rw   = 1'b0; // Block read
                mem_addr = {req_tag, req_index, {OFFSET_WIDTH{1'b0}}};

                if (mem_ready) begin
                    // Store line in cache
                    cache_we_block      = 1'b1;
                    cache_w_block_index = req_index;
                    cache_w_block_tag   = req_tag;
                    cache_w_block_data  = mem_rdata_block;
                    cache_w_block_dirty = (WRITE_POLICY == `POLICY_WRITE_BACK && latched_rw == `OP_WRITE) ? 1'b1 : 1'b0;
                end
            end

            `S_UPDATE: begin
                cpu_ready = 1'b1;
                cpu_hit   = 1'b0;
                cpu_miss  = 1'b1;

                if (latched_rw == `OP_READ) begin
                    cpu_rdata = cpu_rdata_reg;
                end else begin
                    // Write Miss: update modified byte in newly allocated line
                    cache_we_byte       = 1'b1;
                    cache_w_byte_index  = req_index;
                    cache_w_byte_offset = req_offset;
                    cache_w_byte_data   = latched_wdata;

                    if (WRITE_POLICY == `POLICY_WRITE_BACK) begin
                        cache_we_dirty    = 1'b1;
                        cache_w_dirty_val = 1'b1;
                    end else begin
                        // Complete Write-Through to memory if still pending
                        mem_req   = 1'b1;
                        mem_rw    = 1'b1;
                        mem_addr  = latched_addr;
                        if (!mem_ready) begin
                            cpu_ready = 1'b0; // Wait until memory write finishes
                        end
                    end
                end
            end

            default: ;
        endcase
    end

endmodule

