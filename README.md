# FIFO Verification Environment — SystemVerilog

> A structured, layered verification environment for a synchronous FIFO,  
> built using SystemVerilog UVM-inspired concepts without the UVM library.

![Language](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Tool](https://img.shields.io/badge/Tool-QuestaSim_2025.2-purple)
![Status](https://img.shields.io/badge/Status-All_Tests_Passing-brightgreen)
![Methodology](https://img.shields.io/badge/Methodology-UVM--Inspired-teal)

---

## Table of Contents

- [Project Overview](#project-overview)
- [Repository Structure](#repository-structure)
- [DUT Specification](#dut-specification)
- [Verification Architecture](#verification-architecture)
- [Component Breakdown](#component-breakdown)
- [Assertions](#systemverilog-assertions-sva)
- [Functional Coverage](#functional-coverage)
- [Key Design Decisions](#key-design-decisions-and-methodology-notes)
- [How to Run](#how-to-run)
- [Sample Output](#sample-output)
- [Skills Demonstrated](#skills-demonstrated)

---

## Project Overview

This project implements a complete functional verification environment for a
**32-deep × 32-bit synchronous FIFO** with active-HIGH reset. The environment
is architected using the same layered methodology used in industry UVM
testbenches — transaction, generator, driver, monitor, scoreboard, environment,
and test — written in plain SystemVerilog to demonstrate first-principles
understanding of the methodology.

---

## Repository Structure

```
fifo-sv-verification/
├── rtl/
│   └── design.sv          # Synthesizable FIFO DUT
├── tb/
│   └── testbench.sv       # Complete verification environment
├── sim/
│   └── run.sh             # QuestaSim simulation script
└── README.md
```

---

## DUT Specification

| Parameter      | Value                        |
|----------------|------------------------------|
| Data width     | 32 bits                      |
| Depth          | 32 entries                   |
| Reset          | Synchronous, active-HIGH     |
| Full flag      | Count-based (`count == 32`)  |
| Empty flag     | Count-based (`count == 0`)   |
| Read latency   | 1 clock cycle (registered)   |

---

## Verification Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        ENVIRONMENT                           │
│                                                              │
│  ┌─────────────┐   mailbox #(transaction)   ┌─────────────┐  │
│  │  GENERATOR  │ ─────────────────────────► │   DRIVER    │  │
│  │             │                            │ driver_cb   │  │
│  └─────────────┘                            └──────┬──────┘  │
│         │                                          │         │
│      event                                 virtual fifo_if   │
│     drv2gen                                        │         │
│                                             ┌──────▼──────┐  │
│  ┌─────────────┐   mailbox #(transaction)   │   MONITOR   │  │
│  │ SCOREBOARD  │ ◄───────────────────────── │ monitor_cb  │  │
│  │  ref_q[$]   │                            └─────────────┘  │
│  └─────────────┘                                             │
└──────────────────────────────┬───────────────────────────────┘
                               │ virtual interface
                  ┌────────────▼────────────┐
                  │       fifo_if            │
                  │  driver_cb · monitor_cb  │
                  │  SVA assertions          │
                  │  functional covergroup   │
                  └────────────┬────────────┘
                               │
                  ┌────────────▼────────────┐
                  │        FIFO DUT          │
                  │  32-deep × 32-bit        │
                  └─────────────────────────┘
```

---

## Component Breakdown

| Component       | Responsibility |
|-----------------|----------------|
| **transaction** | Data object holding stimulus and response fields. Constraint `wr_en != rd_en` ensures no simultaneous read+write |
| **generator**   | Randomizes `repeat_count` transactions and puts them into a typed mailbox. Signals completion via a SystemVerilog event |
| **driver**      | Retrieves transactions from mailbox, drives DUT through `driver_cb` clocking block with back-pressure handling — suppresses writes when full, reads when empty |
| **monitor**     | Two parallel threads: Thread A captures control signals every cycle, Thread B resolves registered `dout` one cycle later. Sends complete transaction to scoreboard |
| **scoreboard**  | Queue-based reference model. Pushes on write, pops and compares on read. Reports pass/fail with totals |
| **environment** | Instantiates and connects all components. Controls test phases: `pre_test → test → post_test` |
| **interface**   | Bundles all DUT signals. Contains two clocking blocks, SVA assertions, and functional covergroups |

---

## SystemVerilog Assertions (SVA)

Four protocol-level assertions are embedded in the interface:

| Assertion                  | Description |
|---------------------------|-------------|
| `assert_no_overflow`       | Flags any write when FIFO is full |
| `assert_no_underflow`      | Flags any read when FIFO is empty |
| `assert_full_empty_mutex`  | Ensures `full` and `empty` are never both HIGH simultaneously |
| `assert_reset_empties`     | Verifies FIFO reports `empty` the cycle after reset releases |

> All assertions use raw interface signals (not clocking block signals) to avoid
> scheduling race conditions between the Active and Observed simulation regions.

---

## Functional Coverage

Coverage is collected inside the interface covergroup `fifo_cg`:

| Coverpoint      | What it measures |
|-----------------|-----------------|
| `cp_wr`         | Write-enable toggle |
| `cp_rd`         | Read-enable toggle |
| `cp_full`       | FIFO full condition hit |
| `cp_empty`      | FIFO empty condition hit |
| `cp_op`         | Write-only vs read-only operations |
| `cx_op_full`    | Cross: operation type × full status |
| `cx_op_empty`   | Cross: operation type × empty status |

---

## Key Design Decisions and Methodology Notes

**Why no UVM library?**  
Using plain SV with UVM-inspired architecture demonstrates understanding of
*why* the methodology exists — not just how to instantiate macros. Every
mailbox, virtual interface, and event is wired explicitly, making the data
flow visible and debuggable.

**Clocking block discipline**
- Driver drives exclusively through `driver_cb` (output skew `#1`)
- Monitor samples exclusively through `monitor_cb` (input skew `#1`)
- Assertions use raw signals — clocking block signals with `input #0` cause
  scheduling races in the Observed region; raw DUT outputs are stable by then

**Two-thread monitor**  
The FIFO has a registered output — `dout` is valid one cycle *after* `rd_en`
is asserted. A single-thread monitor that waits an extra cycle to capture
`dout` misses control signals in the intervening cycle. The two-thread design solves this:
- Thread A samples `wr_en` / `rd_en` / `din` / `full` / `empty` every active cycle
- Thread B waits exactly one cycle then captures `dout` for pending reads

**Back-pressure in driver**  
The driver samples `full` and `empty` from the clocking block before driving
and silently suppresses illegal operations. This prevents assertion failures
caused by TB-generated stimulus rather than DUT bugs.

**Typed mailboxes**  
All mailboxes are parameterized (`mailbox #(transaction)`) to catch type
mismatches at compile time rather than simulation time.

---

## How to Run

```bash
# QuestaSim
cd sim
vlog ../rtl/design.sv ../tb/testbench.sv
vsim -batch -do "run -all; exit" tb_top
```

To increase transaction count, edit this line in `testbench.sv`:

```systemverilog
env.gen.repeat_count = 20;   // change to any number
```

---

## Sample Output

```
[DRV] Waiting for reset
[DRV] Reset done

[GEN] wr=1 rd=0 din=0x2a57ab54 | dout=0x00000000 full=0 empty=0
[GEN] wr=1 rd=0 din=0x52e67f13 | dout=0x00000000 full=0 empty=0
[GEN] wr=1 rd=0 din=0x33ff5bf0 | dout=0x00000000 full=0 empty=0
[GEN] wr=0 rd=1 din=0x1b94f528 | dout=0x00000000 full=0 empty=0
[GEN] Done — 20 transactions sent

[DRV] WRITE din=0x2a57ab54
[MON] wr=1 rd=0 din=0x2a57ab54 | dout=0x00000000 full=0 empty=1
[SCB] Pushed 0x2a57ab54  depth=1

[DRV] WRITE din=0x52e67f13
[MON] wr=1 rd=0 din=0x52e67f13 | dout=0x00000000 full=0 empty=1
[SCB] Pushed 0x52e67f13  depth=2

[DRV] READ  dout=0x2a57ab54
[MON] wr=0 rd=1 din=0x00000000 | dout=0x2a57ab54 full=0 empty=0
[SCB] PASS expected=0x2a57ab54 got=0x2a57ab54

[DRV] READ  dout=0x52e67f13
[MON] wr=0 rd=1 din=0x00000000 | dout=0x52e67f13 full=0 empty=0
[SCB] PASS expected=0x52e67f13 got=0x52e67f13

[DRV] READ  dout=0x33ff5bf0
[MON] wr=0 rd=1 din=0x00000000 | dout=0x33ff5bf0 full=0 empty=0
[SCB] PASS expected=0x33ff5bf0 got=0x33ff5bf0

[DRV] empty — suppressing read
...

================================
[SCB] TOTAL CHECKS :  8
[SCB] PASSED       :  8
[SCB] FAILED       :  0
[SCB] RESULT       :  ALL PASSED ✓
================================
```

### What the output tells you

| Line | What it means |
|------|--------------|
| `[GEN]` lines appear first | Generator fills the mailbox before driver starts — expected producer-consumer behavior |
| `dout=0x00000000` in GEN lines | Correct — DUT output fields not yet sampled at generation time |
| `[DRV] empty — suppressing read` | Back-pressure logic working — driver detected empty flag and blocked the read |
| `[SCB] FIFO EMPTY` | Scoreboard observed the empty flag asserted — coverage event |
| `depth=N` growing then shrinking | Confirms FIFO is behaving as a queue (FIFO order preserved) |
| `PASS expected=X got=X` | Scoreboard reference model matches DUT output exactly |

---

## Skills Demonstrated

- Layered testbench architecture (UVM methodology without UVM library)
- SystemVerilog OOP: classes, typed mailboxes, virtual interfaces
- Clocking block discipline: driver/monitor separation, skew management
- SystemVerilog Assertions (SVA): concurrent properties, `disable iff`, `|=>`
- Functional coverage: covergroups, cross coverage, per-instance option
- Constrained random verification: `dist`, `!=`, inter-signal constraints
- Reference model design: queue-based scoreboard with pass/fail tracking
- Simulation scheduling: Active vs Observed region awareness
- Reset handling: synchronous active-HIGH, event-based sequencing
- Back-pressure handling: runtime suppression of illegal DUT operations

---

## Tools Used

| Tool        | Version       |
|-------------|---------------|
| QuestaSim   | 2025.2        |
| EDA Playground | Online     |
| Language    | SystemVerilog IEEE 1800-2017 |

---

## Author

Sneha Mummaneni 
[LinkedIn](https://www.linkedin.com/in/snehamummaneni) | [Email](mailto:snehamummaneni184@gmail.com)