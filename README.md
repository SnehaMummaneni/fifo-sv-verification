# FIFO Verification Environment — SystemVerilog

> A structured, layered verification environment for a synchronous FIFO,
> built using SystemVerilog UVM-inspired concepts without the UVM library.

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

| Parameter     | Value                        |
|---------------|------------------------------|
| Data width    | 32 bits                      |
| Depth         | 32 entries                   |
| Reset         | Synchronous, active-HIGH     |
| Full flag     | Count-based (`count == 32`)  |
| Empty flag    | Count-based (`count == 0`)   |
| Read latency  | 1 clock cycle (registered)   |

---

## Verification Environment Architecture

```
┌─────────────────────────────────────────────────────┐
│                   ENVIRONMENT                       |
│                                                     |
│  ┌───────────┐    mailbox     ┌──────────────────┐  │
│  │ GENERATOR │ ─────────────► │     DRIVER       │  │
│  │           │  #(transaction)│  (clocking block)│  │
│  └───────────┘                └────────┬─────────┘  │
│                                        │ virtual if |
│  ┌───────────┐    mailbox     ┌────────▼─────────┐  │
│  │SCOREBOARD │ ◄───────────── │     MONITOR      │  │
│  │ ref_q[$]  │  #(transaction)│  (clocking block)│  │
│  └───────────┘                └──────────────────┘  │
└──────────────────────────┬──────────────────────────┘
                           │ virtual interface
                ┌──────────▼──────────┐
                │    fifo_if          │
                │  (interface +       │
                │   clocking blocks + │
                │   assertions +      │
                │   covergroups)      │
                └──────────┬──────────┘
                           │
                ┌──────────▼──────────┐
                │       FIFO DUT      │
                └─────────────────────┘
```

### Component Breakdown

| Component     | Responsibility |
|---------------|----------------|
| **Transaction** | Data object holding stimulus and response fields; randomization constraints ensure `wr_en != rd_en` (no simultaneous read+write) |
| **Generator** | Randomizes `repeat_count` transactions and puts them into a typed mailbox; signals completion via an event |
| **Driver** | Retrieves transactions from mailbox; drives DUT through clocking block with proper back-pressure handling (suppresses writes when full, reads when empty) |
| **Monitor** | Two parallel threads — one captures control signals every cycle, second resolves registered `dout` one cycle later; sends complete transaction to scoreboard |
| **Scoreboard** | Queue-based reference model; pushes on write, pops and compares on read; reports pass/fail with totals |
| **Environment** | Instantiates and connects all components; controls test phases (`pre_test` → `test` → `post_test`) |
| **Interface** | Bundles all DUT signals; contains two clocking blocks (driver and monitor), SVA assertions, and functional covergroups |

---

## SystemVerilog Assertions (SVA)

Four protocol-level assertions are embedded in the interface:

| Assertion | Description |
|-----------|-------------|
| `assert_no_overflow` | Flags any write when FIFO is full |
| `assert_no_underflow` | Flags any read when FIFO is empty |
| `assert_full_empty_mutex` | Ensures full and empty are never both high simultaneously |
| `assert_reset_empties` | Verifies FIFO reports empty the cycle after reset releases |

All assertions use raw interface signals (not clocking block signals) to avoid
scheduling race conditions between the Active and Observed simulation regions.

---

## Functional Coverage

Coverage is collected inside the interface covergroup `fifo_cg`:

| Coverpoint | What it measures |
|------------|-----------------|
| `cp_wr` | Write-enable toggle |
| `cp_rd` | Read-enable toggle |
| `cp_full` | FIFO full condition hit |
| `cp_empty` | FIFO empty condition hit |
| `cp_op` | Write-only vs read-only operations |
| `cx_op_full` | Cross: operation type × full status |
| `cx_op_empty` | Cross: operation type × empty status |

---

## Key Design Decisions and Methodology Notes

**Why no UVM library?**
Using plain SV with UVM-inspired architecture demonstrates understanding of
*why* the methodology exists — not just how to instantiate macros. Every
mailbox, virtual interface, and event is wired explicitly, making the data
flow visible and debuggable.

**Clocking block discipline**
- Driver drives exclusively through `driver_cb` (output skew #1)
- Monitor samples exclusively through `monitor_cb` (input skew #1)
- Assertions use raw signals — clocking block signals with `input #0` cause
  scheduling races in the Observed region; raw DUT outputs are stable by then

**Two-thread monitor**
The FIFO has a registered output — `dout` is valid one cycle *after* `rd_en`
is asserted. A single-thread monitor that waits an extra cycle to capture
`dout` will miss control signals in the intervening cycle. The two-thread
design solves this:
- Thread A samples `wr_en`/`rd_en`/`din`/`full`/`empty` every active cycle
- Thread B waits exactly one cycle then captures `dout` for pending reads

**Back-pressure in driver**
The driver samples `full` and `empty` from the clocking block before driving,
and silently suppresses illegal operations. This prevents assertion failures
from TB-generated stimulus (as opposed to DUT bugs).

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

# Increase transaction count (edit testbench.sv line in test_prog):
env.gen.repeat_count = 50;
```

---

## Sample Output

```
[GEN] wr=1 rd=0 din=0x3FA21B08 | dout=0x00000000 full=0 empty=0
[DRV] WRITE din=0x3FA21B08
[MON] wr=1 rd=0 din=0x3FA21B08 | dout=0x00000000 full=0 empty=0
[SCB] Pushed 0x3FA21B08  depth=1
[GEN] wr=0 rd=1 din=0x00000000 | dout=0x00000000 full=0 empty=0
[DRV] READ  dout=0x3FA21B08
[MON] wr=0 rd=1 din=0x00000000 | dout=0x3FA21B08 full=0 empty=0
[SCB] PASS expected=0x3FA21B08 got=0x3FA21B08
================================
[SCB] TOTAL CHECKS : 10
[SCB] PASSED       : 10
[SCB] FAILED       : 0
[SCB] RESULT : ALL PASSED ✓
================================
```

---

## Skills Demonstrated

- Layered testbench architecture (UVM methodology without UVM library)
- SystemVerilog OOP: classes, inheritance-ready structure, typed mailboxes
- Clocking block discipline: driver/monitor separation, skew management
- SystemVerilog Assertions (SVA): concurrent properties, `disable iff`, `|=>`
- Functional coverage: covergroups, cross coverage, per-instance option
- Virtual interfaces: decoupling TB components from DUT signal details
- Constrained random verification: `dist`, `!=`, inter-signal constraints
- Reference model design: queue-based scoreboard with pass/fail tracking
- Simulation scheduling: Active vs Observed region awareness
- Reset handling: synchronous active-HIGH, event-based sequencing

---

## Author

**[Your Name]**  
B.Tech / M.Tech — [Your College]  
[LinkedIn URL] | [Email]

---

## Tools

| Tool | Version used |
|------|-------------|
| QuestaSim | 2025.2 |
| EDA Playground | Online |
| Language | SystemVerilog IEEE 1800-2017 |