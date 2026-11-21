// ============================================================================
// File: cache_tb.v
// Project: 16-Bit Direct-Mapped Cache Controller Using Verilog HDL
// Lead Verification Engineer: Member 2 (Verification & Testing Lead)
// Description: Comprehensive, self-checking testbench covering all primary
//              hardware verification scenarios:
//              Suite 1: Cold / Compulsory misses across all 4 cache lines
//              Suite 2: Spatial locality across contiguous line offsets
//              Suite 3: Temporal locality & repeated memory accesses
//              Suite 4: Write hits & Write-Through main memory coherence
//              Suite 5: Write misses (Write-Allocate policy & line refills)
//              Suite 6: Multi-address conflict misses & ping-pong thrashing
//              Suite 7: Sequential multi-block stride-1 memory traversal
//              Suite 8: Pseudo-random access patterns & data integrity checks
//              Performance statistics & hardware PMU metrics evaluation.
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
    // Test Statistics & Hardware PMU Bookkeeping
    // ------------------------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer test_num;

    integer stat_reads;
    integer stat_writes;
    integer stat_read_hits;
    integer stat_read_misses;
    integer stat_write_hits;
    integer stat_write_misses;

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
            stat_reads = stat_reads + 1;
            @(posedge clk);
            cpu_addr  <= addr;
            cpu_rw    <= 1'b0; // Read
            cpu_wdata <= 8'h00;
            cpu_req   <= 1'b1;

            @(posedge clk);
            while (!cpu_ready) begin
                @(posedge clk);
            end

            captured_data = cpu_rdata;
            captured_hit  = cpu_hit;
            cpu_req       <= 1'b0;

            if (captured_hit == 1'b1)
                stat_read_hits = stat_read_hits + 1;
            else
                stat_read_misses = stat_read_misses + 1;

            if ((captured_data === expected_data) && (captured_hit === expected_hit)) begin
                $display("[PASS] Test %02d: %0s | Addr: 0x%04h | Data: 0x%02h (Exp: 0x%02h) | Hit: %b (Exp: %b)",
                         test_num, test_description, addr, captured_data, expected_data, captured_hit, expected_hit);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %02d: %0s | Addr: 0x%04h | Data: 0x%02h (Exp: 0x%02h) | Hit: %b (Exp: %b)",
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
            stat_writes = stat_writes + 1;
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

            if (captured_hit == 1'b1)
                stat_write_hits = stat_write_hits + 1;
            else
                stat_write_misses = stat_write_misses + 1;

            if (captured_hit === expected_hit) begin
                $display("[PASS] Test %02d: %0s | Addr: 0x%04h | WData: 0x%02h | Hit: %b (Exp: %b)",
                         test_num, test_description, addr, data_to_write, captured_hit, expected_hit);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %02d: %0s | Addr: 0x%04h | WData: 0x%02h | Hit: %b (Exp: %b)",
                         test_num, test_description, addr, data_to_write, captured_hit, expected_hit);
                fail_count = fail_count + 1;
            end

            @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------------------
    // Task: Direct Memory Array Coherence Check
    // ------------------------------------------------------------------------
    task check_memory_byte;
        input [15:0] addr;
        input [7:0]  expected_val;
        input [255:0] desc;
        begin
            test_num = test_num + 1;
            if (u_main_memory.memory_array[addr] === expected_val) begin
                $display("[PASS] Test %02d: %0s (Addr 0x%04h == 0x%02h)", test_num, desc, addr, expected_val);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %02d: %0s Failed! (Addr 0x%04h == 0x%02h, Exp: 0x%02h)",
                         test_num, desc, addr, u_main_memory.memory_array[addr], expected_val);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ------------------------------------------------------------------------
    // Main Verification Stimulus Routine
    // ------------------------------------------------------------------------
    initial begin
        $dumpfile("simulation/waveforms/cache_sim.vcd");
        $dumpvars(0, cache_tb);

        pass_count        = 0;
        fail_count        = 0;
        test_num          = 0;
        stat_reads        = 0;
        stat_writes       = 0;
        stat_read_hits    = 0;
        stat_read_misses  = 0;
        stat_write_hits   = 0;
        stat_write_misses = 0;

        cpu_req   = 1'b0;
        cpu_rw    = 1'b0;
        cpu_addr  = 16'h0000;
        cpu_wdata = 8'h00;
        rst_n     = 1'b1;

        // Pre-seed benchmark patterns in main memory
        u_main_memory.memory_array[16'h0034] = 8'hA0;
        u_main_memory.memory_array[16'h0035] = 8'hA1;
        u_main_memory.memory_array[16'h0036] = 8'hA2;
        u_main_memory.memory_array[16'h0037] = 8'hA3;

        u_main_memory.memory_array[16'h0044] = 8'hC0;
        u_main_memory.memory_array[16'h0045] = 8'hC1;
        u_main_memory.memory_array[16'h0046] = 8'hC2;
        u_main_memory.memory_array[16'h0047] = 8'hC3;

        u_main_memory.memory_array[16'h0054] = 8'hD0;
        u_main_memory.memory_array[16'h0055] = 8'hD1;
        u_main_memory.memory_array[16'h0056] = 8'hD2;
        u_main_memory.memory_array[16'h0057] = 8'hD3;

        u_main_memory.memory_array[16'h0010] = 8'h10;
        u_main_memory.memory_array[16'h0011] = 8'h11;
        u_main_memory.memory_array[16'h0012] = 8'h12;
        u_main_memory.memory_array[16'h0013] = 8'h13;

        u_main_memory.memory_array[16'h0028] = 8'h28;
        u_main_memory.memory_array[16'h0029] = 8'h29;
        u_main_memory.memory_array[16'h002A] = 8'h2A;
        u_main_memory.memory_array[16'h002B] = 8'h2B;

        u_main_memory.memory_array[16'h003C] = 8'h3C;
        u_main_memory.memory_array[16'h003D] = 8'h3D;
        u_main_memory.memory_array[16'h003E] = 8'h3E;
        u_main_memory.memory_array[16'h003F] = 8'h3F;

        $display("============================================================================");
        $display("  16-BIT DIRECT-MAPPED CACHE CONTROLLER: HARDWARE VERIFICATION SUITE");
        $display("  Lead Verification Engineer: Member 2 (Verification & Testing Lead)");
        $display("============================================================================");

        // Reset sequence
        #10 rst_n = 1'b0;
        #25 rst_n = 1'b1;
        #20;

        // --------------------------------------------------------------------
        // Suite 1: Cold / Compulsory Misses across all 4 cache lines
        // --------------------------------------------------------------------
        $display("\n--- Suite 1: Cold / Compulsory Misses Across All 4 Lines ---");
        cpu_read_check(16'h0010, 8'h10, 1'b0, "Line 0 Cold Miss (Tag 0x001, Index 0)");
        cpu_read_check(16'h0034, 8'hA0, 1'b0, "Line 1 Cold Miss (Tag 0x003, Index 1)");
        cpu_read_check(16'h0028, 8'h28, 1'b0, "Line 2 Cold Miss (Tag 0x002, Index 2)");
        cpu_read_check(16'h003C, 8'h3C, 1'b0, "Line 3 Cold Miss (Tag 0x003, Index 3)");

        // --------------------------------------------------------------------
        // Suite 2: Spatial Locality across contiguous line offsets
        // --------------------------------------------------------------------
        $display("\n--- Suite 2: Spatial Locality Verification Across Offsets ---");
        cpu_read_check(16'h0035, 8'hA1, 1'b1, "Line 1 Offset 1 Spatial Hit (0x0035)");
        cpu_read_check(16'h0036, 8'hA2, 1'b1, "Line 1 Offset 2 Spatial Hit (0x0036)");
        cpu_read_check(16'h0037, 8'hA3, 1'b1, "Line 1 Offset 3 Spatial Hit (0x0037)");
        cpu_read_check(16'h0011, 8'h11, 1'b1, "Line 0 Offset 1 Spatial Hit (0x0011)");
        cpu_read_check(16'h0029, 8'h29, 1'b1, "Line 2 Offset 1 Spatial Hit (0x0029)");
        cpu_read_check(16'h003E, 8'h3E, 1'b1, "Line 3 Offset 2 Spatial Hit (0x003E)");

        // --------------------------------------------------------------------
        // Suite 3: Temporal Locality & Repeated Memory Accesses
        // --------------------------------------------------------------------
        $display("\n--- Suite 3: Temporal Locality & Repeated Memory Accesses ---");
        cpu_read_check(16'h0034, 8'hA0, 1'b1, "Temporal Re-access: Line 1 Base Hit");
        cpu_read_check(16'h0034, 8'hA0, 1'b1, "Temporal Repeated Read 2: Line 1 Hit");
        cpu_read_check(16'h0010, 8'h10, 1'b1, "Temporal Re-access: Line 0 Base Hit");
        cpu_read_check(16'h0028, 8'h28, 1'b1, "Temporal Re-access: Line 2 Base Hit");
        cpu_read_check(16'h003C, 8'h3C, 1'b1, "Temporal Re-access: Line 3 Base Hit");

        // --------------------------------------------------------------------
        // Suite 4: Write Hit Operations & Write-Through Memory Coherence
        // --------------------------------------------------------------------
        $display("\n--- Suite 4: Write Hit Operations & Write-Through Memory Coherence ---");
        cpu_write_check(16'h0035, 8'h55, 1'b1, "Write Hit: Update Line 1 Offset 1 with 0x55");
        cpu_read_check(16'h0035, 8'h55, 1'b1, "Read Back: Verify Cache Read After Write Hit");
        check_memory_byte(16'h0035, 8'h55, "Write-Through Memory Coherence (0x0035 == 0x55)");

        cpu_write_check(16'h0010, 8'hAA, 1'b1, "Write Hit: Update Line 0 Offset 0 with 0xAA");
        cpu_read_check(16'h0010, 8'hAA, 1'b1, "Read Back: Verify Cache Line 0 Updated");
        check_memory_byte(16'h0010, 8'hAA, "Write-Through Memory Coherence (0x0010 == 0xAA)");

        // --------------------------------------------------------------------
        // Suite 5: Write Miss Operations (Write-Allocate Policy & Line Allocation)
        // --------------------------------------------------------------------
        $display("\n--- Suite 5: Write Miss (Write-Allocate Policy & Line Allocation) ---");
        u_main_memory.memory_array[16'h0068] = 8'h68;
        u_main_memory.memory_array[16'h0069] = 8'h69;
        u_main_memory.memory_array[16'h006A] = 8'h6A;
        u_main_memory.memory_array[16'h006B] = 8'h6B;

        cpu_write_check(16'h0068, 8'h77, 1'b0, "Write Miss (Write-Allocate) at 0x0068");
        cpu_read_check(16'h0068, 8'h77, 1'b1, "Read Back After Write Miss: Verify Hit on 0x0068");
        cpu_read_check(16'h0069, 8'h69, 1'b1, "Preservation Check: Adjacent Byte in Line 2");
        check_memory_byte(16'h0068, 8'h77, "Write Miss Memory Coherence (0x0068 == 0x77)");

        // --------------------------------------------------------------------
        // Suite 6: Multi-Address Conflict Misses & Ping-Pong Thrashing
        // --------------------------------------------------------------------
        $display("\n--- Suite 6: Multi-Address Conflict Misses & Ping-Pong Thrashing ---");
        cpu_read_check(16'h0044, 8'hC0, 1'b0, "Conflict Miss: 0x0044 evicts 0x0034 on Line 1");
        cpu_read_check(16'h0044, 8'hC0, 1'b1, "Immediate Re-Read: 0x0044 is now Hit on Line 1");
        cpu_read_check(16'h0054, 8'hD0, 1'b0, "Conflict Miss: 0x0054 evicts 0x0044 on Line 1");
        cpu_read_check(16'h0034, 8'hA0, 1'b0, "Conflict Miss: 0x0034 evicts 0x0054 on Line 1");
        cpu_read_check(16'h0044, 8'hC0, 1'b0, "Ping-Pong Thrash: 0x0044 evicts 0x0034 again");

        // --------------------------------------------------------------------
        // Suite 7: Sequential Multi-Block Stride-1 Access Pattern
        // --------------------------------------------------------------------
        $display("\n--- Suite 7: Sequential Multi-Block Stride-1 Access Pattern ---");
        u_main_memory.memory_array[16'h0070] = 8'h70;
        u_main_memory.memory_array[16'h0071] = 8'h71;
        u_main_memory.memory_array[16'h0072] = 8'h72;
        u_main_memory.memory_array[16'h0073] = 8'h73;
        u_main_memory.memory_array[16'h0074] = 8'h74;
        u_main_memory.memory_array[16'h0075] = 8'h75;
        u_main_memory.memory_array[16'h0076] = 8'h76;
        u_main_memory.memory_array[16'h0077] = 8'h77;

        cpu_read_check(16'h0070, 8'h70, 1'b0, "Sequential Block 1 Base: 0x0070 (Cold Miss)");
        cpu_read_check(16'h0071, 8'h71, 1'b1, "Sequential Stride: 0x0071 (Spatial Hit)");
        cpu_read_check(16'h0072, 8'h72, 1'b1, "Sequential Stride: 0x0072 (Spatial Hit)");
        cpu_read_check(16'h0073, 8'h73, 1'b1, "Sequential Stride: 0x0073 (Spatial Hit)");
        cpu_read_check(16'h0074, 8'h74, 1'b0, "Sequential Block 2 Base: 0x0074 (Cold Miss)");
        cpu_read_check(16'h0075, 8'h75, 1'b1, "Sequential Stride: 0x0075 (Spatial Hit)");
        cpu_read_check(16'h0076, 8'h76, 1'b1, "Sequential Stride: 0x0076 (Spatial Hit)");
        cpu_read_check(16'h0077, 8'h77, 1'b1, "Sequential Stride: 0x0077 (Spatial Hit)");

        // --------------------------------------------------------------------
        // Suite 8: Pseudo-Random Access Verification & Interleaved R/W
        // --------------------------------------------------------------------
        $display("\n--- Suite 8: Pseudo-Random Access Verification & Interleaved R/W ---");
        cpu_write_check(16'h0012, 8'h88, 1'b0, "Random Interleaved Write: 0x0012 <- 0x88");
        cpu_read_check(16'h0012, 8'h88, 1'b1, "Random Verification Read: 0x0012 returns 0x88");
        // Note: 0x0012 evicted 0x0070-0x0073 from Line 0 (Tag 0x001 vs Tag 0x007), so 0x0072 is a Conflict Write Miss!
        cpu_write_check(16'h0072, 8'h99, 1'b0, "Conflict Write Miss: 0x0072 evicts 0x0012 on Line 0");
        cpu_read_check(16'h0072, 8'h99, 1'b1, "Random Verification Read: 0x0072 returns 0x99");

        // --------------------------------------------------------------------
        // Verification Summary Report & PMU Statistics
        // --------------------------------------------------------------------
        #50;
        $display("============================================================================");
        $display("  HARDWARE PERFORMANCE MONITORING UNIT (PMU) & HIT/MISS STATISTICS");
        $display("============================================================================");
        $display("  Total CPU Accesses Evaluated : %0d", (stat_reads + stat_writes));
        $display("    - Total Read Accesses      : %0d (Hits: %0d, Misses: %0d)", stat_reads, stat_read_hits, stat_read_misses);
        $display("    - Total Write Accesses     : %0d (Hits: %0d, Misses: %0d)", stat_writes, stat_write_hits, stat_write_misses);
        $display("  Overall Hits / Misses        : %0d Hits / %0d Misses", (stat_read_hits + stat_write_hits), (stat_read_misses + stat_write_misses));
        $display("============================================================================");
        $display("  Total Formal Assertions      : %0d", test_num);
        $display("  Assertions Passed            : %0d", pass_count);
        $display("  Assertions Failed            : %0d", fail_count);
        if (fail_count == 0) begin
            $display("  FINAL VERIFICATION STATUS    : >>> ALL FORMAL ASSERTIONS PASSED (100%%) <<<");
        end else begin
            $display("  FINAL VERIFICATION STATUS    : >>> VERIFICATION FAILED WITH %0d ERRORS <<<", fail_count);
        end
        $display("============================================================================");

        $finish;
    end

endmodule
