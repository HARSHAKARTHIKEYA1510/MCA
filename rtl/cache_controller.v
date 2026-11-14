// ============================================================================
// File: cache_controller.v
// Project: 16-Bit Direct-Mapped Cache Controller Using Verilog HDL
// Description: Master Finite State Machine (FSM) implementing:
//              - CPU request decoding (12-bit Tag, 2-bit Index, 2-bit Offset)
//              - Hit/Miss detection
//              - Line allocation on read/write misses (Write-Allocate)
//              - Main memory write-through coordination (Write-Through)
//              - Single-cycle acknowledge and completion signaling
// Standard: Verilog-2001 (IEEE 1364-2001)
// ============================================================================

`timescale 1ns / 1ps

module cache_controller (
    input  wire        clk,
    input  wire        rst_n,

    // ------------------------------------------------------------------------
    // CPU Interface
    // ------------------------------------------------------------------------
    input  wire        cpu_req,          // CPU access strobe
    input  wire        cpu_rw,           // 0: Read, 1: Write
    input  wire [15:0] cpu_addr,         // 16-bit address [15:4]=Tag, [3:2]=Index, [1:0]=Offset
    input  wire [7:0]  cpu_wdata,        // 8-bit CPU write data
    output reg  [7:0]  cpu_rdata,        // 8-bit CPU read data
    output reg         cpu_ready,        // Ready / Acknowledge pulse (1 cycle)
    output reg         cpu_hit,          // Hit status (1: Hit, 0: Miss)

    // ------------------------------------------------------------------------
    // Cache Memory Interface
    // ------------------------------------------------------------------------
    output wire [1:0]  cache_r_index,
    output wire [1:0]  cache_r_offset,
    input  wire        cache_r_valid,
    input  wire [11:0] cache_r_tag,
    input  wire [7:0]  cache_r_byte,
    input  wire [31:0] cache_r_block,

    output reg         cache_we_block,
    output reg  [1:0]  cache_w_block_index,
    output reg  [11:0] cache_w_block_tag,
    output reg  [31:0] cache_w_block_data,

    output reg         cache_we_byte,
    output reg  [1:0]  cache_w_byte_index,
    output reg  [1:0]  cache_w_byte_offset,
    output reg  [7:0]  cache_w_byte_data,

    // ------------------------------------------------------------------------
    // Main Memory Interface
    // ------------------------------------------------------------------------
    output reg         mem_req,
    output reg         mem_rw,           // 0: Read 4-Byte Block, 1: Write Byte
    output reg  [15:0] mem_addr,
    output reg  [7:0]  mem_wdata,
    input  wire [31:0] mem_rdata_block,
    input  wire        mem_ready
);

    // ------------------------------------------------------------------------
    // FSM State Encodings
    // ------------------------------------------------------------------------
    localparam [2:0]
        S_IDLE          = 3'b000,
        S_LOOKUP        = 3'b001,
        S_READ_MISS     = 3'b010,
        S_ALLOCATE      = 3'b011,
        S_WRITE_THROUGH = 3'b100,
        S_COMPLETE      = 3'b101;

    reg [2:0] state, next_state;

    // ------------------------------------------------------------------------
    // Latched Request Registers
    // ------------------------------------------------------------------------
    reg [15:0] latched_addr;
    reg        latched_rw;
    reg [7:0]  latched_wdata;
    reg        latched_hit;
    reg [7:0]  cpu_rdata_reg;
    reg [31:0] latched_mem_block;

    // Address decomposition of latched CPU address
    wire [11:0] req_tag    = latched_addr[15:4];
    wire [1:0]  req_index  = latched_addr[3:2];
    wire [1:0]  req_offset = latched_addr[1:0];

    // Driven read index/offset to cache memory
    assign cache_r_index  = (state == S_IDLE) ? cpu_addr[3:2] : req_index;
    assign cache_r_offset = (state == S_IDLE) ? cpu_addr[1:0] : req_offset;

    // Hit evaluation
    wire hit_condition = (cache_r_valid == 1'b1) && (cache_r_tag == req_tag);

    // Byte extraction helper for block data
    function [7:0] select_byte_from_block;
        input [31:0] block;
        input [1:0]  offset;
        begin
            case (offset)
                2'b00: select_byte_from_block = block[7:0];
                2'b01: select_byte_from_block = block[15:8];
                2'b10: select_byte_from_block = block[23:16];
                2'b11: select_byte_from_block = block[31:24];
            endcase
        end
    endfunction

    // ------------------------------------------------------------------------
    // Synchronous FSM State Update & Datapath Registers
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= S_IDLE;
            latched_addr      <= 16'h0000;
            latched_rw        <= 1'b0;
            latched_wdata     <= 8'h00;
            latched_hit       <= 1'b0;
            cpu_rdata_reg     <= 8'h00;
            latched_mem_block <= 32'h00000000;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    if (cpu_req) begin
                        latched_addr  <= cpu_addr;
                        latched_rw    <= cpu_rw;
                        latched_wdata <= cpu_wdata;
                    end
                end

                S_LOOKUP: begin
                    latched_hit <= hit_condition;
                    if (hit_condition) begin
                        if (latched_rw == 1'b0) begin
                            // Read Hit
                            cpu_rdata_reg <= cache_r_byte;
                        end
                    end
                end

                S_READ_MISS: begin
                    if (mem_ready) begin
                        latched_mem_block <= mem_rdata_block;
                    end
                end

                S_ALLOCATE: begin
                    if (latched_rw == 1'b0) begin
                        // Read Miss: select byte from the freshly allocated block
                        cpu_rdata_reg <= select_byte_from_block(latched_mem_block, req_offset);
                    end
                end

                S_WRITE_THROUGH: begin
                    // Write committed to memory upon mem_ready
                end

                S_COMPLETE: begin
                    // Output held for 1 cycle, returned to IDLE
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
            S_IDLE: begin
                if (cpu_req) begin
                    next_state = S_LOOKUP;
                end
            end

            S_LOOKUP: begin
                if (hit_condition) begin
                    if (latched_rw == 1'b0) begin
                        // Read Hit: complete immediately
                        next_state = S_COMPLETE;
                    end else begin
                        // Write Hit: cache updated, must write-through to main memory
                        next_state = S_WRITE_THROUGH;
                    end
                end else begin
                    // Cache Miss (both Read Miss and Write Miss allocate first under Write-Allocate)
                    next_state = S_READ_MISS;
                end
            end

            S_READ_MISS: begin
                if (mem_ready) begin
                    next_state = S_ALLOCATE;
                end
            end

            S_ALLOCATE: begin
                if (latched_rw == 1'b0) begin
                    // Read Miss allocated: complete
                    next_state = S_COMPLETE;
                end else begin
                    // Write Miss allocated & updated: now write-through to memory
                    next_state = S_WRITE_THROUGH;
                end
            end

            S_WRITE_THROUGH: begin
                if (mem_ready) begin
                    next_state = S_COMPLETE;
                end
            end

            S_COMPLETE: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // Combinational Output & Control Logic
    // ------------------------------------------------------------------------
    always @(*) begin
        // Default outputs
        cpu_ready           = 1'b0;
        cpu_hit             = latched_hit;
        cpu_rdata           = cpu_rdata_reg;

        cache_we_block      = 1'b0;
        cache_w_block_index = req_index;
        cache_w_block_tag   = req_tag;
        cache_w_block_data  = latched_mem_block;

        cache_we_byte       = 1'b0;
        cache_w_byte_index  = req_index;
        cache_w_byte_offset = req_offset;
        cache_w_byte_data   = latched_wdata;

        mem_req             = 1'b0;
        mem_rw              = 1'b0;
        mem_addr            = 16'h0000;
        mem_wdata           = latched_wdata;

        case (state)
            S_IDLE: begin
                // Dormant
            end

            S_LOOKUP: begin
                if (hit_condition && (latched_rw == 1'b1)) begin
                    // Write Hit: update cache line byte immediately
                    cache_we_byte = 1'b1;
                end
            end

            S_READ_MISS: begin
                // Fetch missing 4-byte block from main memory
                mem_req  = 1'b1;
                mem_rw   = 1'b0; // Read block
                mem_addr = {req_tag, req_index, 2'b00};
            end

            S_ALLOCATE: begin
                // Write fetched 4-byte block, tag, and valid bit into cache
                cache_we_block      = 1'b1;
                cache_w_block_index = req_index;
                cache_w_block_tag   = req_tag;
                cache_w_block_data  = latched_mem_block;

                if (latched_rw == 1'b1) begin
                    // Write Miss (Write-Allocate): overwrite modified byte in cache
                    cache_we_byte       = 1'b1;
                    cache_w_byte_index  = req_index;
                    cache_w_byte_offset = req_offset;
                    cache_w_byte_data   = latched_wdata;
                end
            end

            S_WRITE_THROUGH: begin
                // Write single byte through to main memory
                mem_req   = 1'b1;
                mem_rw    = 1'b1; // Write byte
                mem_addr  = latched_addr;
                mem_wdata = latched_wdata;
            end

            S_COMPLETE: begin
                // Pulsed acknowledge to CPU
                cpu_ready = 1'b1;
                cpu_hit   = latched_hit;
                cpu_rdata = cpu_rdata_reg;
            end

            default: ;
        endcase
    end

endmodule
