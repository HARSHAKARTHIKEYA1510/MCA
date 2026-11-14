// ============================================================================
// File: main_memory.v
// Project: 16-Bit Direct-Mapped Cache Controller Using Verilog HDL
// Description: Behavioral model of byte-addressable main memory supporting:
//              - 4-byte block burst read operations
//              - Single-byte write-through operations
//              - Configurable memory access latency simulation
//              - Deterministic memory completion signaling (mem_ready)
// Standard: Verilog-2001 (IEEE 1364-2001)
// ============================================================================

`timescale 1ns / 1ps

module main_memory #(
    parameter MEM_SIZE_BYTES = 1024,     // Size of simulated physical memory space
    parameter LATENCY_CYCLES = 2         // Clock cycles before completion
)(
    input  wire        clk,
    input  wire        rst_n,

    // Memory Bus Interface
    input  wire        mem_req,          // Memory request strobe
    input  wire        mem_rw,           // 0: Read 4-Byte Block, 1: Write Single Byte
    input  wire [15:0] mem_addr,         // 16-bit physical memory address
    input  wire [7:0]  mem_wdata,        // 8-bit write data byte
    output reg  [31:0] mem_rdata_block,  // 32-bit (4-byte) block: {Byte3, Byte2, Byte1, Byte0}
    output reg         mem_ready         // Handshake completion pulse
);

    // ------------------------------------------------------------------------
    // Physical Byte Storage Array
    // ------------------------------------------------------------------------
    reg [7:0] memory_array [0:MEM_SIZE_BYTES-1];

    // Latency counter & state tracking
    reg [3:0] latency_counter;
    reg       busy;

    // Base block address (aligned to 4-byte boundary)
    wire [15:0] block_base_addr = {mem_addr[15:2], 2'b00};

    integer i;

    // ------------------------------------------------------------------------
    // Memory Operation & Latency Engine
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready       <= 1'b0;
            mem_rdata_block <= 32'h00000000;
            latency_counter <= 4'd0;
            busy            <= 1'b0;

            // Initialize memory with predictable test patterns:
            // Byte pattern: memory[k] = k & 8'hFF, with special seeds for benchmark addresses
            for (i = 0; i < MEM_SIZE_BYTES; i = i + 1) begin
                memory_array[i] <= i[7:0];
            end

            // Explicit benchmark data for 0x0034 - 0x0037 (Line 1, Tag 0x003)
            memory_array[16'h0034] <= 8'hA0;
            memory_array[16'h0035] <= 8'hA1;
            memory_array[16'h0036] <= 8'hA2;
            memory_array[16'h0037] <= 8'hA3;

            // Explicit benchmark data for 0x0044 - 0x0047 (Line 1, Tag 0x004 - Conflict)
            memory_array[16'h0044] <= 8'hC0;
            memory_array[16'h0045] <= 8'hC1;
            memory_array[16'h0046] <= 8'hC2;
            memory_array[16'h0047] <= 8'hC3;

            // Explicit benchmark data for Line 0 (0x0010 - 0x0013)
            memory_array[16'h0010] <= 8'h10;
            memory_array[16'h0011] <= 8'h11;
            memory_array[16'h0012] <= 8'h12;
            memory_array[16'h0013] <= 8'h13;

            // Explicit benchmark data for Line 2 (0x0028 - 0x002B)
            memory_array[16'h0028] <= 8'h28;
            memory_array[16'h0029] <= 8'h29;
            memory_array[16'h002A] <= 8'h2A;
            memory_array[16'h002B] <= 8'h2B;

            // Explicit benchmark data for Line 3 (0x003C - 0x003F)
            memory_array[16'h003C] <= 8'h3C;
            memory_array[16'h003D] <= 8'h3D;
            memory_array[16'h003E] <= 8'h3E;
            memory_array[16'h003F] <= 8'h3F;

        end else begin
            mem_ready <= 1'b0; // Default pulse deassertion

            if (mem_req && !busy) begin
                busy            <= 1'b1;
                latency_counter <= 4'd1;
            end else if (busy) begin
                if (latency_counter < LATENCY_CYCLES) begin
                    latency_counter <= latency_counter + 4'd1;
                end else begin
                    // Latency satisfied: execute operation
                    busy            <= 1'b0;
                    latency_counter <= 4'd0;
                    mem_ready       <= 1'b1;

                    if (mem_rw == 1'b0) begin
                        // Read 4-byte block
                        mem_rdata_block <= {memory_array[block_base_addr + 16'd3],
                                            memory_array[block_base_addr + 16'd2],
                                            memory_array[block_base_addr + 16'd1],
                                            memory_array[block_base_addr + 16'd0]};
                    end else begin
                        // Write single byte
                        memory_array[mem_addr] <= mem_wdata;
                    end
                end
            end
        end
    end

endmodule
