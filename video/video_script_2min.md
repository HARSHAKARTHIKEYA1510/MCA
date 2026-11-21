# 2-Minute Demo Video Script
## Direct-Mapped Cache Controller Using Verilog HDL

> **Target:** ≤ 300 words | Medium pace (~150 wpm) | Total ≈ 2 minutes  
> **Screen actions are in** `[brackets]`

---

## 🎤 MEMBER 1 — Intro + Architecture  `[0:00 – 0:50]`

**[Show desktop / project folder open in Finder or VS Code]**

> "Hello everyone. We are a team of three — [Student 1 Name], [Student 2 Name], and [Student 3 Name] — presenting our MCA project:
> *Design and Implementation of a Direct-Mapped Cache Controller using Verilog HDL.*
>
> The core problem we address is the **memory wall** — the CPU is much faster than main memory, so a cache is placed between them to reduce latency.
>
> We designed a **direct-mapped cache** with a **16-bit address**, decomposed as:
> — 12-bit Tag | 2-bit Index | 2-bit Offset
>
> The cache holds **4 lines × 4 bytes = 16 bytes** total, uses **Write-Through** and **Write-Allocate** policies, and is controlled by a **6-state FSM**."

**[Open `rtl/cache_controller.v` — scroll slowly to show FSM state names: S_IDLE, S_LOOKUP, S_READ_MISS, S_ALLOCATE, S_WRITE_THROUGH, S_COMPLETE]**

---

## 🎤 MEMBER 2 — Live Demo  `[0:50 – 1:30]`

**[Open VS Code Explorer — briefly show the 4 RTL files: `cache_controller.v`, `cache_memory.v`, `main_memory.v`, `direct_mapped_cache.v`]**

> "Our design has four Verilog modules. Let me run the simulation now."

**[Open Terminal. Navigate to project folder. Run:]**
```
python3 scripts/simulate_cache.py
```

**[Let output scroll — pause on the PASS lines]**

> "All **20 out of 20 test assertions PASSED** — 100% success rate.
>
> One key test: addresses `0x0034` and `0x0044` both map to **Index 1** but have **different tags** — 0x003 vs 0x004. This triggers a **conflict miss and cache line replacement**, which our controller handles correctly."

**[Open `simulation/logs/simulation.log` — scroll to the bottom showing 20/20 PASS]**

---

## 🎤 MEMBER 3 — Conclusion  `[1:30 – 2:00]`

**[Open `docs/IEEE_Report/IEEE_report.pdf` — show title page briefly]**

> "To summarize — we successfully implemented and verified a synthesizable direct-mapped cache controller in Verilog, backed by an IEEE-format Phase I report and a full GitHub repository.
>
> For Phase II, we plan to extend this to a **2-way set-associative cache** with a **Write-Back policy**.
>
> Thank you for watching."

---

## 📂 FILES TO OPEN (in order)

| Timestamp | Action | File / Command |
|-----------|--------|----------------|
| 0:00 | Show project folder | `MCA/` in Finder or VS Code Explorer |
| 0:20 | Open & scroll | `rtl/cache_controller.v` (FSM states) |
| 0:50 | Show Explorer sidebar | All 4 RTL files in `rtl/` |
| 1:00 | Run in Terminal | `python3 scripts/simulate_cache.py` |
| 1:20 | Open | `simulation/logs/simulation.log` |
| 1:30 | Open | `docs/IEEE_Report/IEEE_report.pdf` |

---

> **⚠️ Faculty Note:** College instructions list 5 members; our actual team has 3. This discrepancy has been flagged for faculty clarification.
