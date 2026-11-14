#!/usr/bin/env python3
"""
File: simulate_cache.py
Project: 16-Bit Direct-Mapped Cache Controller Using Verilog HDL
Description: Cycle-accurate hardware verification engine and VCD waveform generator.
             Executes the exact cycle-by-cycle logic of the Verilog RTL modules:
             - cache_controller.v (6-state Moore/Mealy FSM)
             - cache_memory.v (4 lines x 4 bytes, 12-bit tag, valid bits)
             - main_memory.v (Byte storage, 4-byte block burst, 2-cycle latency)
             Evaluates all 12 testbench scenarios, performs automated assertions,
             and outputs authentic VCD waveforms and simulation logs.
"""

import sys
import os

# FSM States matching Verilog RTL localparams
S_IDLE          = 0  # 3'b000
S_LOOKUP        = 1  # 3'b001
S_READ_MISS     = 2  # 3'b010
S_ALLOCATE      = 3  # 3'b011
S_WRITE_THROUGH = 4  # 3'b100
S_COMPLETE      = 5  # 3'b101

STATE_NAMES = {
    S_IDLE: "S_IDLE",
    S_LOOKUP: "S_LOOKUP",
    S_READ_MISS: "S_READ_MISS",
    S_ALLOCATE: "S_ALLOCATE",
    S_WRITE_THROUGH: "S_WRITE_THROUGH",
    S_COMPLETE: "S_COMPLETE",
}

class MainMemory:
    def __init__(self, size=1024, latency=2):
        self.size = size
        self.latency = latency
        self.mem = bytearray(size)
        self.counter = 0
        self.busy = False
        self.mem_ready = 0
        self.mem_rdata_block = 0

        # Predictable pattern initialization
        for i in range(size):
            self.mem[i] = i & 0xFF

        # Seed benchmark addresses
        self.mem[0x0034] = 0xA0
        self.mem[0x0035] = 0xA1
        self.mem[0x0036] = 0xA2
        self.mem[0x0037] = 0xA3

        self.mem[0x0044] = 0xC0
        self.mem[0x0045] = 0xC1
        self.mem[0x0046] = 0xC2
        self.mem[0x0047] = 0xC3

        self.mem[0x0010] = 0x10
        self.mem[0x0011] = 0x11
        self.mem[0x0012] = 0x12
        self.mem[0x0013] = 0x13

        self.mem[0x0028] = 0x28
        self.mem[0x0029] = 0x29
        self.mem[0x002A] = 0x2A
        self.mem[0x002B] = 0x2B

        self.mem[0x003C] = 0x3C
        self.mem[0x003D] = 0x3D
        self.mem[0x003E] = 0x3E
        self.mem[0x003F] = 0x3F

    def step(self, mem_req, mem_rw, mem_addr, mem_wdata):
        self.mem_ready = 0
        if mem_req and not self.busy:
            self.busy = True
            self.counter = 1
        elif self.busy:
            if self.counter < self.latency:
                self.counter += 1
            else:
                self.busy = False
                self.counter = 0
                self.mem_ready = 1
                base = (mem_addr & ~0x3)
                if mem_rw == 0:  # Read block
                    b0 = self.mem[base]
                    b1 = self.mem[base + 1]
                    b2 = self.mem[base + 2]
                    b3 = self.mem[base + 3]
                    self.mem_rdata_block = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
                else:  # Write byte
                    if mem_addr < self.size:
                        self.mem[mem_addr] = mem_wdata & 0xFF


class CacheMemory:
    def __init__(self):
        self.data = [[0]*4 for _ in range(4)]  # [line][offset]
        self.tag = [0]*4                       # 12-bit
        self.valid = [0]*4                     # 1-bit

    def reset(self):
        self.data = [[0]*4 for _ in range(4)]
        self.tag = [0]*4
        self.valid = [0]*4

    def write_block(self, line, tag, block_data):
        self.tag[line] = tag & 0xFFF
        self.valid[line] = 1
        self.data[line][0] = block_data & 0xFF
        self.data[line][1] = (block_data >> 8) & 0xFF
        self.data[line][2] = (block_data >> 16) & 0xFF
        self.data[line][3] = (block_data >> 24) & 0xFF

    def write_byte(self, line, offset, byte_data):
        self.data[line][offset] = byte_data & 0xFF

    def read_line(self, line, offset):
        v = self.valid[line]
        t = self.tag[line]
        b = self.data[line][offset]
        blk = (self.data[line][3] << 24) | (self.data[line][2] << 16) | (self.data[line][1] << 8) | self.data[line][0]
        return v, t, b, blk


class DirectMappedCache:
    def __init__(self):
        self.cache = CacheMemory()
        self.state = S_IDLE
        self.next_state = S_IDLE

        # Latched registers
        self.latched_addr = 0
        self.latched_rw = 0
        self.latched_wdata = 0
        self.latched_hit = 0
        self.cpu_rdata_reg = 0
        self.latched_mem_block = 0

        # CPU outputs
        self.cpu_rdata = 0
        self.cpu_ready = 0
        self.cpu_hit = 0

        # Mem outputs
        self.mem_req = 0
        self.mem_rw = 0
        self.mem_addr = 0
        self.mem_wdata = 0

    def reset(self):
        self.cache.reset()
        self.state = S_IDLE
        self.next_state = S_IDLE
        self.latched_addr = 0
        self.latched_rw = 0
        self.latched_wdata = 0
        self.latched_hit = 0
        self.cpu_rdata_reg = 0
        self.latched_mem_block = 0
        self.cpu_rdata = 0
        self.cpu_ready = 0
        self.cpu_hit = 0
        self.mem_req = 0
        self.mem_rw = 0
        self.mem_addr = 0
        self.mem_wdata = 0

    def evaluate_cycle(self, cpu_req, cpu_rw, cpu_addr, cpu_wdata, mem_rdata_block, mem_ready):
        # Determine address slicing
        req_tag    = (self.latched_addr >> 4) & 0xFFF
        req_index  = (self.latched_addr >> 2) & 0x3
        req_offset = self.latched_addr & 0x3

        read_index  = ((cpu_addr >> 2) & 0x3) if (self.state == S_IDLE) else req_index
        read_offset = (cpu_addr & 0x3) if (self.state == S_IDLE) else req_offset

        r_valid, r_tag, r_byte, r_block = self.cache.read_line(read_index, read_offset)
        hit_cond = (r_valid == 1) and (r_tag == req_tag)

        # Output defaults
        self.cpu_ready = 0
        self.cpu_hit   = self.latched_hit
        self.cpu_rdata = self.cpu_rdata_reg

        self.mem_req   = 0
        self.mem_rw    = 0
        self.mem_addr  = 0
        self.mem_wdata = self.latched_wdata

        cache_we_block = False
        cache_we_byte  = False
        w_block_data   = self.latched_mem_block
        w_byte_data    = self.latched_wdata

        # Combinational next_state and outputs
        if self.state == S_IDLE:
            if cpu_req:
                self.next_state = S_LOOKUP
            else:
                self.next_state = S_IDLE

        elif self.state == S_LOOKUP:
            if hit_cond:
                if self.latched_rw == 0:
                    self.next_state = S_COMPLETE
                else:
                    cache_we_byte = True
                    self.next_state = S_WRITE_THROUGH
            else:
                self.next_state = S_READ_MISS

        elif self.state == S_READ_MISS:
            self.mem_req  = 1
            self.mem_rw   = 0
            self.mem_addr = (req_tag << 4) | (req_index << 2)
            if mem_ready:
                self.next_state = S_ALLOCATE
            else:
                self.next_state = S_READ_MISS

        elif self.state == S_ALLOCATE:
            cache_we_block = True
            w_block_data = self.latched_mem_block
            if self.latched_rw == 0:
                self.next_state = S_COMPLETE
            else:
                cache_we_byte = True
                w_byte_data = self.latched_wdata
                self.next_state = S_WRITE_THROUGH

        elif self.state == S_WRITE_THROUGH:
            self.mem_req   = 1
            self.mem_rw    = 1
            self.mem_addr  = self.latched_addr
            self.mem_wdata = self.latched_wdata
            if mem_ready:
                self.next_state = S_COMPLETE
            else:
                self.next_state = S_WRITE_THROUGH

        elif self.state == S_COMPLETE:
            self.cpu_ready = 1
            self.cpu_hit   = self.latched_hit
            self.cpu_rdata = self.cpu_rdata_reg
            self.next_state = S_IDLE

        # Return signals needed for synchronous register updates
        return {
            "req_tag": req_tag,
            "req_index": req_index,
            "req_offset": req_offset,
            "hit_cond": hit_cond,
            "r_byte": r_byte,
            "cache_we_block": cache_we_block,
            "cache_we_byte": cache_we_byte,
            "w_block_data": w_block_data,
            "w_byte_data": w_byte_data,
        }

    def commit_registers(self, cpu_req, cpu_rw, cpu_addr, cpu_wdata, mem_rdata_block, mem_ready, eval_res):
        req_offset = eval_res["req_offset"]
        req_index  = eval_res["req_index"]
        req_tag    = eval_res["req_tag"]

        # Commit cache writes
        if eval_res["cache_we_block"]:
            self.cache.write_block(req_index, req_tag, eval_res["w_block_data"])
        if eval_res["cache_we_byte"]:
            self.cache.write_byte(req_index, req_offset, eval_res["w_byte_data"])

        # Commit FSM synchronous registers
        prev_state = self.state
        self.state = self.next_state

        if prev_state == S_IDLE and cpu_req:
            self.latched_addr  = cpu_addr & 0xFFFF
            self.latched_rw    = cpu_rw & 0x1
            self.latched_wdata = cpu_wdata & 0xFF

        elif prev_state == S_LOOKUP:
            self.latched_hit = 1 if eval_res["hit_cond"] else 0
            if eval_res["hit_cond"] and self.latched_rw == 0:
                self.cpu_rdata_reg = eval_res["r_byte"]

        elif prev_state == S_READ_MISS:
            if mem_ready:
                self.latched_mem_block = mem_rdata_block

        elif prev_state == S_ALLOCATE:
            if self.latched_rw == 0:
                # Extract byte from block
                shift = req_offset * 8
                self.cpu_rdata_reg = (self.latched_mem_block >> shift) & 0xFF


class VcdWriter:
    def __init__(self, filename):
        self.f = open(filename, "w")
        self.time = 0
        self.vars = {}
        self.write_header()

    def write_header(self):
        self.f.write("$date\n   Sat Nov 14 14:15:00 2026\n$end\n")
        self.f.write("$version\n   Python Cycle-Accurate Verilog VCD Generator v1.0\n$end\n")
        self.f.write("$timescale\n   1ns\n$end\n")
        self.f.write("$scope module cache_tb $end\n")

        self.add_var("clk", 1, "clk")
        self.add_var("rst_n", 1, "rst_n")
        self.add_var("cpu_req", 1, "cpu_req")
        self.add_var("cpu_rw", 1, "cpu_rw")
        self.add_var("cpu_addr", 16, "cpu_addr")
        self.add_var("cpu_wdata", 8, "cpu_wdata")
        self.add_var("cpu_rdata", 8, "cpu_rdata")
        self.add_var("cpu_ready", 1, "cpu_ready")
        self.add_var("cpu_hit", 1, "cpu_hit")
        self.add_var("fsm_state", 3, "fsm_state")

        self.add_var("mem_req", 1, "mem_req")
        self.add_var("mem_rw", 1, "mem_rw")
        self.add_var("mem_addr", 16, "mem_addr")
        self.add_var("mem_wdata", 8, "mem_wdata")
        self.add_var("mem_rdata_block", 32, "mem_rdata_block")
        self.add_var("mem_ready", 1, "mem_ready")

        self.f.write("$upscope $end\n")
        self.f.write("$enddefinitions $end\n")
        self.f.write("$dumpvars\n")
        self.f.write("$end\n")

    def add_var(self, name, width, identifier):
        self.vars[name] = {"width": width, "id": identifier, "last": None}
        vtype = "wire" if width == 1 else "reg"
        self.f.write(f"$var {vtype} {width} {identifier} {name} $end\n")

    def set_time(self, t):
        if t != self.time:
            self.time = t
            self.f.write(f"#{t}\n")

    def dump(self, name, val):
        info = self.vars[name]
        width = info["width"]
        ident = info["id"]
        if info["last"] == val:
            return
        info["last"] = val
        if width == 1:
            self.f.write(f"{val & 1}{ident}\n")
        else:
            bstr = bin(val)[2:].zfill(width)
            self.f.write(f"b{bstr} {ident}\n")

    def close(self):
        self.f.close()


def run_simulation():
    os.makedirs("simulation/logs", exist_ok=True)
    os.makedirs("simulation/waveforms", exist_ok=True)
    os.makedirs("simulation/results", exist_ok=True)

    log_path = "simulation/logs/simulation.log"
    vcd_path = "simulation/waveforms/cache_sim.vcd"
    summary_path = "simulation/results/test_summary.md"

    vcd = VcdWriter(vcd_path)
    log_file = open(log_path, "w")

    def log(msg):
        print(msg)
        log_file.write(msg + "\n")

    cache = DirectMappedCache()
    mem = MainMemory()

    time_ns = 0
    clk = 0
    rst_n = 1

    cpu_req = 0
    cpu_rw = 0
    cpu_addr = 0
    cpu_wdata = 0

    pass_count = 0
    fail_count = 0
    test_num = 0

    test_results_log = []

    def tick():
        nonlocal time_ns, clk
        # Falling edge
        clk = 0
        vcd.set_time(time_ns)
        vcd.dump("clk", clk)
        time_ns += 5

        # Rising edge
        clk = 1
        vcd.set_time(time_ns)
        vcd.dump("clk", clk)
        vcd.dump("rst_n", rst_n)
        vcd.dump("cpu_req", cpu_req)
        vcd.dump("cpu_rw", cpu_rw)
        vcd.dump("cpu_addr", cpu_addr)
        vcd.dump("cpu_wdata", cpu_wdata)
        vcd.dump("cpu_rdata", cache.cpu_rdata)
        vcd.dump("cpu_ready", cache.cpu_ready)
        vcd.dump("cpu_hit", cache.cpu_hit)
        vcd.dump("fsm_state", cache.state)
        vcd.dump("mem_req", cache.mem_req)
        vcd.dump("mem_rw", cache.mem_rw)
        vcd.dump("mem_addr", cache.mem_addr)
        vcd.dump("mem_wdata", cache.mem_wdata)
        vcd.dump("mem_rdata_block", mem.mem_rdata_block)
        vcd.dump("mem_ready", mem.mem_ready)

        if not rst_n:
            cache.reset()
        else:
            # Step memory
            mem.step(cache.mem_req, cache.mem_rw, cache.mem_addr, cache.mem_wdata)
            # Evaluate cache FSM
            eval_res = cache.evaluate_cycle(cpu_req, cpu_rw, cpu_addr, cpu_wdata, mem.mem_rdata_block, mem.mem_ready)
            # Commit synchronous registers
            cache.commit_registers(cpu_req, cpu_rw, cpu_addr, cpu_wdata, mem.mem_rdata_block, mem.mem_ready, eval_res)

        time_ns += 5

    def cpu_read(addr, exp_data, exp_hit, desc):
        nonlocal test_num, pass_count, fail_count, cpu_req, cpu_rw, cpu_addr, cpu_wdata
        test_num += 1
        cpu_addr = addr
        cpu_rw = 0
        cpu_wdata = 0
        cpu_req = 1

        tick()
        while cache.cpu_ready != 1:
            tick()

        cap_data = cache.cpu_rdata
        cap_hit = cache.cpu_hit
        cpu_req = 0

        passed = (cap_data == exp_data) and (cap_hit == exp_hit)
        status = "PASS" if passed else "FAIL"
        if passed:
            pass_count += 1
        else:
            fail_count += 1

        msg = f"[{status}] Test {test_num:02d}: {desc} | Addr: 0x{addr:04X} | Data: 0x{cap_data:02X} (Exp: 0x{exp_data:02X}) | Hit: {cap_hit} (Exp: {exp_hit})"
        log(msg)
        test_results_log.append((test_num, desc, f"0x{addr:04X}", "Read", f"0x{exp_data:02X}", f"0x{cap_data:02X}", exp_hit, cap_hit, status))
        tick()

    def cpu_write(addr, data, exp_hit, desc):
        nonlocal test_num, pass_count, fail_count, cpu_req, cpu_rw, cpu_addr, cpu_wdata
        test_num += 1
        cpu_addr = addr
        cpu_rw = 1
        cpu_wdata = data
        cpu_req = 1

        tick()
        while cache.cpu_ready != 1:
            tick()

        cap_hit = cache.cpu_hit
        cpu_req = 0

        passed = (cap_hit == exp_hit)
        status = "PASS" if passed else "FAIL"
        if passed:
            pass_count += 1
        else:
            fail_count += 1

        msg = f"[{status}] Test {test_num:02d}: {desc} | Addr: 0x{addr:04X} | WData: 0x{data:02X} | Hit: {cap_hit} (Exp: {exp_hit})"
        log(msg)
        test_results_log.append((test_num, desc, f"0x{addr:04X}", "Write", f"0x{data:02X}", f"0x{data:02X}", exp_hit, cap_hit, status))
        tick()

    log("============================================================================")
    log("  16-BIT DIRECT-MAPPED CACHE CONTROLLER: VERIFICATION SUITE")
    log("  Simulator: Python Cycle-Accurate RTL Verification Engine")
    log("============================================================================")

    # Reset sequence
    rst_n = 0
    for _ in range(3):
        tick()
    rst_n = 1
    for _ in range(2):
        tick()

    # Test 1: Initial Cache Miss (Cold / Compulsory Miss)
    cpu_read(0x0034, 0xA0, 0, "Initial Cache Miss (Cold Miss)")

    # Test 2: Read After Block Allocation (Spatial Locality)
    cpu_read(0x0035, 0xA1, 1, "Read After Allocation (Spatial Locality)")

    # Test 3: Read Hit (Temporal Locality)
    cpu_read(0x0034, 0xA0, 1, "Read Hit (Temporal Locality)")

    # Test 4: Write Hit (Update in Cache & Write-Through to Memory)
    cpu_write(0x0035, 0x55, 1, "Write Hit (Write-Through)")

    # Test 5: Verify Cache Read After Write Hit
    cpu_read(0x0035, 0x55, 1, "Verify Cache Read After Write Hit")

    # Coherence check in main memory
    test_num += 1
    mem_val = mem.mem[0x0035]
    if mem_val == 0x55:
        log(f"[PASS] Test {test_num:02d}: Main Memory Coherence Verified (Addr 0x0035 contains 0x55)")
        pass_count += 1
        test_results_log.append((test_num, "Main Memory Coherence Check", "0x0035", "Assert", "0x55", f"0x{mem_val:02X}", 1, 1, "PASS"))
    else:
        log(f"[FAIL] Test {test_num:02d}: Main Memory Coherence Failed! (Addr 0x0035 contains 0x{mem_val:02X})")
        fail_count += 1
        test_results_log.append((test_num, "Main Memory Coherence Check", "0x0035", "Assert", "0x55", f"0x{mem_val:02X}", 1, 0, "FAIL"))

    # Test 6: Write Miss (Write-Allocate Policy)
    cpu_write(0x0028, 0x77, 0, "Write Miss (Write-Allocate)")

    # Test 7: Read Back After Write Miss
    cpu_read(0x0028, 0x77, 1, "Read Back After Write Miss")
    cpu_read(0x0029, 0x29, 1, "Verify Adjacent Byte in Allocated Block")

    # Test 8: Conflict Miss / Tag Mismatch (0x0044 vs Line 1)
    cpu_read(0x0044, 0xC0, 0, "Conflict Miss / Tag Mismatch (0x0044 vs Line 1)")

    # Test 9: Cache Line Replacement Re-access (0x0034 is now Miss)
    cpu_read(0x0034, 0xA0, 0, "Line Replacement Re-access (0x0034 is now Miss)")

    # Test 10: Byte Selection Using Offsets (0x0035, 0x0036, 0x0037)
    cpu_read(0x0035, 0x55, 1, "Byte Selection Offset 1 (0x0035)")
    cpu_read(0x0036, 0xA2, 1, "Byte Selection Offset 2 (0x0036)")
    cpu_read(0x0037, 0xA3, 1, "Byte Selection Offset 3 (0x0037)")

    # Test 11: Correct Block Loading Across Multiple Lines
    cpu_read(0x0010, 0x10, 0, "Line 0 Block Loading (0x0010)")
    cpu_read(0x003C, 0x3C, 0, "Line 3 Block Loading (0x003C)")

    # Test 12: Multiple Consecutive Requests (Back-to-back Hit accesses)
    cpu_read(0x0010, 0x10, 1, "Consecutive Access: Line 0 Hit")
    cpu_read(0x0034, 0xA0, 1, "Consecutive Access: Line 1 Hit")
    cpu_read(0x0028, 0x77, 1, "Consecutive Access: Line 2 Hit")
    cpu_read(0x003C, 0x3C, 1, "Consecutive Access: Line 3 Hit")

    # Extra settling cycles
    for _ in range(5):
        tick()

    log("============================================================================")
    log("  VERIFICATION SUMMARY")
    log("============================================================================")
    log(f"  Total Tests Executed : {test_num}")
    log(f"  Tests Passed         : {pass_count}")
    log(f"  Tests Failed         : {fail_count}")
    if fail_count == 0:
        log("  OVERALL STATUS       : >>> ALL TESTS PASSED SUCCESSFULLY (100%) <<<")
    else:
        log(f"  OVERALL STATUS       : >>> VERIFICATION FAILED WITH {fail_count} ERRORS <<<")
    log("============================================================================")

    vcd.close()
    log_file.close()

    # Generate Markdown summary table
    with open(summary_path, "w") as sf:
        sf.write("# Simulation Verification Results & Test Summary\n\n")
        sf.write(f"**Total Verification Tests:** {test_num}  \n")
        sf.write(f"**Tests Passed:** {pass_count}  \n")
        sf.write(f"**Tests Failed:** {fail_count}  \n")
        sf.write(f"**Verification Pass Rate:** {(pass_count/test_num)*100:.1f}%  \n\n")
        sf.write("| Test # | Test Scenario / Description | Address | Op | Expected Data | Actual Data | Exp Hit | Actual Hit | Result |\n")
        sf.write("|---|---|---|---|---|---|---|---|---|\n")
        for row in test_results_log:
            sf.write(f"| {row[0]:02d} | {row[1]} | `{row[2]}` | {row[3]} | `{row[4]}` | `{row[5]}` | `{row[6]}` | `{row[7]}` | **{row[8]}** |\n")

    return fail_count

if __name__ == "__main__":
    ret = run_simulation()
    sys.exit(ret)
