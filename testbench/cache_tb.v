// ============================================================================
// File: cache_tb.v
// Project: 16-Bit Direct-Mapped Cache Controller Using Verilog HDL
// Description: Comprehensive, self-checking testbench covering all 12 mandatory
//              verification scenarios:
//              1. Initial cache miss (cold miss)
//              2. Read after block allocation (spatial locality)
//              3. Read hit (temporal locality)
//              4. Write hit
//              5. Write miss (write-allocate)
//              6. Memory update after write-through
//              7. Two addresses mapping to the same cache line (0x0034 & 0x0044)
//              8. Tag mismatch detection
//              9. Cache line replacement
//             10. Multiple consecutive requests
//             11. Correct byte selection using offsets (0, 1, 2, 3)
//             12. Correct block loading across all 4 cache lines
// Standard: Verilog-2001 (IEEE 1364-2001)
// ============================================================================

`timescale 1ns / 1ps

module cache_tb;

    // ------------------------------------------------------------------------
    // Clock & Reset Signals
    // ------------------------------------------------------------------------
    reg clk;
    reg rst_n;

    // ------------------------------------------------------------------------
    // CPU Interface Signals
    // ------------------------------------------------------------------------
    reg         cpu_req;
    reg         cpu_rw;
    reg  [15:0] cpu_addr;
    reg  [7:0]  cpu_wdata;
    wire [7:0]  cpu_rdata;
    wire        cpu_ready;
    wire        cpu_hit;

    // ------------------------------------------------------------------------
    // Memory Interface Interconnect
    // ------------------------------------------------------------------------
    wire        mem_req;
    wire        mem_rw;
    wire [15:0] mem_addr;
    wire [7:0]  mem_wdata;
    wire [31:0] mem_rdata_block;
    wire        mem_ready;

    // ------------------------------------------------------------------------
    // Test Statistics & Bookkeeping
    // ------------------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer test_num;

    // ------------------------------------------------------------------------
    // DUT Instantiations
    // ------------------------------------------------------------------------
    direct_mapped_cache u_cache (
        .clk             (clk),
        .rst_n           (rst_n),
        .cpu_req         (cpu_req),
        .cpu_rw          (cpu_rw),
        .cpu_addr        (cpu_addr),
        .cpu_wdata       (cpu_wdata),
        .cpu_rdata       (cpu_rdata),
        .cpu_ready       (cpu_ready),
        .cpu_hit         (cpu_hit),
        .mem_req         (mem_req),
        .mem_rw          (mem_rw),
        .mem_addr        (mem_addr),
        .mem_wdata       (mem_wdata),
        .mem_rdata_block (mem_rdata_block),
        .mem_ready       (mem_ready)
    );

    main_memory #(
        .MEM_SIZE_BYTES  (1024),
        .LATENCY_CYCLES  (2)
    ) u_main_memory (
        .clk             (clk),
        .rst_n           (rst_n),
        .mem_req         (mem_req),
        .mem_rw          (mem_rw),
        .mem_addr        (mem_addr),
        .mem_wdata       (mem_wdata),
        .mem_rdata_block (mem_rdata_block),
        .mem_ready       (mem_ready)
    );

    // ------------------------------------------------------------------------
    // Clock Generation: 100 MHz (10 ns period)
    // ------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Task: CPU Read Transaction with Automated Assertion
    // ------------------------------------------------------------------------
    task cpu_read_check;
        input [15:0] addr;
        input [7:0]  expected_data;
        input        expected_hit;
        input [255:0] test_description;
        reg [7:0]    captured_data;
        reg          captured_hit;
        begin
            test_num = test_num + 1;
            @(posedge clk);
            cpu_addr  <= addr;
            cpu_rw    <= 1'b0; // Read
            cpu_wdata <= 8'h00;
            cpu_req   <= 1'b1;

            // Wait for handshake completion
            @(posedge clk);
            while (!cpu_ready) begin
                @(posedge clk);
            end

            captured_data = cpu_rdata;
            captured_hit  = cpu_hit;
            cpu_req       <= 1'b0;

            // Verification assertion
            if ((captured_data === expected_data) && (captured_hit === expected_hit)) begin
                $display("[PASS] Test %0d: %0s | Addr: 0x%04h | Data: 0x%02h (Exp: 0x%02h) | Hit: %b (Exp: %b)",
                         test_num, test_description, addr, captured_data, expected_data, captured_hit, expected_hit);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %0s | Addr: 0x%04h | Data: 0x%02h (Exp: 0x%02h) | Hit: %b (Exp: %b)",
                         test_num, test_description, addr, captured_data, expected_data, captured_hit, expected_hit);
                fail_count = fail_count + 1;
            end

            @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------------------
    // Task: CPU Write Transaction with Automated Assertion
    // ------------------------------------------------------------------------
    task cpu_write_check;
        input [15:0] addr;
        input [7:0]  data_to_write;
        input        expected_hit;
        input [255:0] test_description;
        reg          captured_hit;
        begin
            test_num = test_num + 1;
            @(posedge clk);
            cpu_addr  <= addr;
            cpu_rw    <= 1'b1; // Write
            cpu_wdata <= data_to_write;
            cpu_req   <= 1'b1;

            @(posedge clk);
            while (!cpu_ready) begin
                @(posedge clk);
            end

            captured_hit = cpu_hit;
            cpu_req      <= 1'b0;

            if (captured_hit === expected_hit) begin
                $display("[PASS] Test %0d: %0s | Addr: 0x%04h | WData: 0x%02h | Hit: %b (Exp: %b)",
                         test_num, test_description, addr, data_to_write, captured_hit, expected_hit);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %0s | Addr: 0x%04h | WData: 0x%02h | Hit: %b (Exp: %b)",
                         test_num, test_description, addr, data_to_write, captured_hit, expected_hit);
                fail_count = fail_count + 1;
            end

            @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------------------
    // Main Verification Stimulus Routine
    // ------------------------------------------------------------------------
    initial begin
        // Waveform configuration
        $dumpfile("simulation/waveforms/cache_sim.vcd");
        $dumpvars(0, cache_tb);

        // Initialize variables
        pass_count = 0;
        fail_count = 0;
        test_num   = 0;
        cpu_req    = 1'b0;
        cpu_rw     = 1'b0;
        cpu_addr   = 16'h0000;
        cpu_wdata  = 8'h00;
        rst_n      = 1'b1;

        $display("============================================================================");
        $display("  16-BIT DIRECT-MAPPED CACHE CONTROLLER: VERIFICATION SUITE");
        $display("============================================================================");

        // Reset sequence
        #10 rst_n = 1'b0;
        #25 rst_n = 1'b1;
        #20;

        // --------------------------------------------------------------------
        // Test 1: Initial Cache Miss (Cold / Compulsory Miss)
        // Addr 0x0034: Tag=0x003, Index=1, Offset=0
        // Expect: Miss (Hit=0), returns 0xA0 fetched from Main Memory
        // --------------------------------------------------------------------
        cpu_read_check(16'h0034, 8'hA0, 1'b0, "Initial Cache Miss (Cold Miss)");

        // --------------------------------------------------------------------
        // Test 2: Read After Block Allocation (Spatial Locality)
        // Addr 0x0035: Tag=0x003, Index=1, Offset=1 (same line already loaded)
        // Expect: Hit (Hit=1), returns 0xA1 from Cache without memory access
        // --------------------------------------------------------------------
        cpu_read_check(16'h0035, 8'hA1, 1'b1, "Read After Allocation (Spatial Locality)");

        // --------------------------------------------------------------------
        // Test 3: Read Hit (Temporal Locality)
        // Addr 0x0034: Re-read same address
        // Expect: Hit (Hit=1), returns 0xA0
        // --------------------------------------------------------------------
        cpu_read_check(16'h0034, 8'hA0, 1'b1, "Read Hit (Temporal Locality)");

        // --------------------------------------------------------------------
        // Test 4: Write Hit (Update in Cache & Write-Through to Memory)
        // Addr 0x0035: Write 0x55 into Line 1, Offset 1
        // Expect: Hit (Hit=1)
        // --------------------------------------------------------------------
        cpu_write_check(16'h0035, 8'h55, 1'b1, "Write Hit (Write-Through)");

        // --------------------------------------------------------------------
        // Test 5: Verify Cache Update After Write Hit
        // Addr 0x0035: Read back updated value
        // Expect: Hit (Hit=1), returns 0x55
        // --------------------------------------------------------------------
        cpu_read_check(16'h0035, 8'h55, 1'b1, "Verify Cache Read After Write Hit");

        // Direct memory verification assertion for write-through
        test_num = test_num + 1;
        if (u_main_memory.memory_array[16'h0035] === 8'h55) begin
            $display("[PASS] Test %0d: Main Memory Coherence Verified (Addr 0x0035 contains 0x55)", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d: Main Memory Coherence Failed! (Addr 0x0035 contains 0x%02h)",
                     test_num, u_main_memory.memory_array[16'h0035]);
            fail_count = fail_count + 1;
        end

        // --------------------------------------------------------------------
        // Test 6: Write Miss (Write-Allocate Policy)
        // Addr 0x0028: Tag=0x002, Index=2, Offset=0 (Line 2 is empty)
        // Expect: Miss (Hit=0), allocates block then updates cache & memory with 0x77
        // --------------------------------------------------------------------
        cpu_write_check(16'h0028, 8'h77, 1'b0, "Write Miss (Write-Allocate)");

        // --------------------------------------------------------------------
        // Test 7: Read After Write Miss Allocation
        // Addr 0x0028: Read back modified byte
        // Expect: Hit (Hit=1), returns 0x77
        // --------------------------------------------------------------------
        cpu_read_check(16'h0028, 8'h77, 1'b1, "Read Back After Write Miss");

        // Verify adjacent byte in allocated Line 2 (Offset 1 = 0x0029, original data 0x29)
        cpu_read_check(16'h0029, 8'h29, 1'b1, "Verify Adjacent Byte in Allocated Block");

        // --------------------------------------------------------------------
        // Test 8: Two Addresses Mapping to Same Cache Line (Conflict Miss)
        // Addr 0x0044: Tag=0x004, Index=1, Offset=0
        // Note: Line 1 currently holds Tag 0x003 (from 0x0034)
        // Expect: Miss (Hit=0), Tag Mismatch -> Evicts 0x0034, fetches 0x0044
        // --------------------------------------------------------------------
        cpu_read_check(16'h0044, 8'hC0, 1'b0, "Conflict Miss / Tag Mismatch (0x0044 vs Line 1)");

        // --------------------------------------------------------------------
        // Test 9: Cache Line Replacement Verification
        // Addr 0x0034: Now evicted because Line 1 holds Tag 0x004
        // Expect: Miss (Hit=0), re-allocates 0x0034 into Line 1
        // --------------------------------------------------------------------
        cpu_read_check(16'h0034, 8'hA0, 1'b0, "Line Replacement Re-access (0x0034 is now Miss)");

        // --------------------------------------------------------------------
        // Test 10: Correct Byte Selection Using Offsets (Line 1 Offsets 0, 1, 2, 3)
        // Line 1 is now reloaded with block 0x0034-0x0037
        // Offset 0: 0x0034 -> 0xA0 (Hit)
        // Offset 1: 0x0035 -> 0x55 (Hit, preserved by write-through to memory!)
        // Offset 2: 0x0036 -> 0xA2 (Hit)
        // Offset 3: 0x0037 -> 0xA3 (Hit)
        // --------------------------------------------------------------------
        cpu_read_check(16'h0035, 8'h55, 1'b1, "Byte Selection Offset 1 (0x0035)");
        cpu_read_check(16'h0036, 8'hA2, 1'b1, "Byte Selection Offset 2 (0x0036)");
        cpu_read_check(16'h0037, 8'hA3, 1'b1, "Byte Selection Offset 3 (0x0037)");

        // --------------------------------------------------------------------
        // Test 11: Correct Block Loading Across Multiple Lines
        // Line 0: Addr 0x0010 (Tag 0x001, Index 0) -> Miss, returns 0x10
        // Line 3: Addr 0x003C (Tag 0x003, Index 3) -> Miss, returns 0x3C
        // --------------------------------------------------------------------
        cpu_read_check(16'h0010, 8'h10, 1'b0, "Line 0 Block Loading (0x0010)");
        cpu_read_check(16'h003C, 8'h3C, 1'b0, "Line 3 Block Loading (0x003C)");

        // --------------------------------------------------------------------
        // Test 12: Multiple Consecutive Requests (Back-to-back Hit accesses)
        // Access Line 0, Line 1, Line 2, Line 3 consecutively
        // --------------------------------------------------------------------
        cpu_read_check(16'h0010, 8'h10, 1'b1, "Consecutive Access: Line 0 Hit");
        cpu_read_check(16'h0034, 8'hA0, 1'b1, "Consecutive Access: Line 1 Hit");
        cpu_read_check(16'h0028, 8'h77, 1'b1, "Consecutive Access: Line 2 Hit");
        cpu_read_check(16'h003C, 8'h3C, 1'b1, "Consecutive Access: Line 3 Hit");

        // --------------------------------------------------------------------
        // Verification Summary Report
        // --------------------------------------------------------------------
        #50;
        $display("============================================================================");
        $display("  VERIFICATION SUMMARY");
        $display("============================================================================");
        $display("  Total Tests Executed : %0d", test_num);
        $display("  Tests Passed         : %0d", pass_count);
        $display("  Tests Failed         : %0d", fail_count);
        if (fail_count == 0) begin
            $display("  OVERALL STATUS       : >>> ALL TESTS PASSED SUCCESSFULLY (100%%) <<<");
        end else begin
            $display("  OVERALL STATUS       : >>> VERIFICATION FAILED WITH %0d ERRORS <<<", fail_count);
        end
        $display("============================================================================");

        $finish;
    end

endmodule
