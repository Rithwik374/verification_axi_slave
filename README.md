# AXI FIFO Slave UVM Verification Environment

This project contains a SystemVerilog/UVM testbench for verifying an AXI FIFO slave. The environment generates AXI write and read traffic, drives all five AXI channels, supports multiple outstanding requests, and tracks responses by AXI ID. Directed tests cover fixed, incrementing, and wrapping bursts.

## Main File

- `uvm_code.sv` - UVM package, sequences, agents, drivers, monitors, scoreboard shell, tests, and top-level simulation module.

## Features

- Parameterized AXI address, data, ID, and user widths
- Random AXI write and read transactions
- FIXED, INCR, and WRAP burst address calculation
- Aligned and unaligned incrementing-burst sequences
- Aligned and unaligned wrapping-burst sequences
- Automatic write-strobe generation
- Independent AXI channel handling for:
  - Write address (`AW`)
  - Write data (`W`)
  - Write response (`B`)
  - Read address (`AR`)
  - Read data (`R`)
- Active/passive UVM agent configuration
- Write and read monitors connected to scoreboard analysis FIFOs
- Transaction tracking by AXI ID
- Driver-side support for multiple outstanding transactions
- Out-of-order response handling across different AXI IDs
- FIFO response ordering for transactions that use the same AXI ID
- Read-beat tracking through `RID` and transaction completion through `RLAST`

## UVM Architecture

```text
top
└── test
    └── env
        ├── wr_agt_top
        │   └── wr_agent
        │       ├── wr_sqr
        │       ├── wr_driver
        │       └── wr_monitor
        ├── rd_agt_top
        │   └── rd_agent
        │       ├── rd_sqr
        │       ├── rd_driver
        │       └── rd_monitor
        └── score_board
```

The write driver currently drives both write and read AXI traffic. The read agent is configured as passive by the base test and observes read-channel activity.

## Outstanding and Out-of-Order Transactions

The driver is designed to accept new sequence items without waiting for earlier AXI responses to complete. Each item is copied into separate write and read request queues, allowing several transactions to remain outstanding at the same time.

### Write Path

- Accepted write requests are recorded in per-ID queues.
- Write data follows write-address order because AXI4 has no `WID` and does not permit write-data interleaving.
- A write response is matched using `BID`.
- Responses with different IDs may complete out of issue order.
- Responses using the same ID are matched to the oldest outstanding request for that ID.

### Read Path

- Accepted read requests are recorded in per-ID queues.
- Each read-data beat is matched using `RID`.
- Beat counts are maintained independently for each outstanding read transaction.
- `RLAST` completes the current transaction for that ID.
- Read data from different IDs may be returned out of order or interleaved.
- Transactions using the same ID remain ordered.

This follows the AXI ordering rule: transactions with different IDs may complete out of order, while transactions with the same ID must preserve ordering.

The driver-side infrastructure is under active development. The monitors and scoreboard still need equivalent per-ID reconstruction before out-of-order behavior can be checked end to end.

## Available Tests

| Test | Sequence | Purpose |
|---|---|---|
| `test` | `wr_seq` | Random AXI write/read transaction |
| `fixed_test` | `fixed_seq` | FIXED burst |
| `inc_align_test` | `inc_align_seq` | Aligned INCR burst |
| `inc_unalign_test` | `inc_unalign_seq` | Unaligned INCR burst |
| `wrap_align_test` | `wrap_align_seq` | Directed aligned WRAP burst |
| `wrap_unalign_test` | `wrap_unalign_seq` | Repeated randomized traffic capable of creating multiple outstanding requests |

The checked-in `top` module calls:

```systemverilog
run_test("test");
```

To run another test, either change that string or allow your simulator's `+UVM_TESTNAME=<test_name>` option by changing the call to:

```systemverilog
run_test();
```

## Dependencies

The testbench expects the following sources or libraries:

- A SystemVerilog simulator with UVM support
- `uvm_pkg` and `uvm_macros.svh`
- `axi_fifo_slave_pkg`
- `axi_fifo_slave_if`
- DUT module `axi_fifo_slave_top`

The AXI package must define the transaction types and constants used by the testbench, including:

- `axi_awar_t`
- `axi_wbeat_t`
- `axi_bresp_t`
- `axi_rbeat_t`
- `axi_resp_e`
- `AXI_BURST_FIXED`, `AXI_BURST_INCR`, and `AXI_BURST_WRAP`
- `DATA_W` and `MEM_BYTES`

Compile the package and interface before `uvm_code.sv`.

## Suggested Compile Order

```text
1. AXI type/package source
2. AXI interface source
3. AXI FIFO slave RTL and its dependencies
4. uvm_code.sv
```

## Example Simulation Commands

Adjust filenames and library options to match the local project.

### Questa/ModelSim

```sh
vlog -sv <axi_package>.sv <axi_interface>.sv <dut_sources>.sv uvm_code.sv
vsim -c top +UVM_TESTNAME=fixed_test -do "run -all; quit"
```

### Synopsys VCS

```sh
vcs -sverilog -ntb_opts uvm <axi_package>.sv <axi_interface>.sv <dut_sources>.sv uvm_code.sv -top top
./simv +UVM_TESTNAME=fixed_test
```

If `run_test("test")` remains hard-coded, the command-line test name may not override it. Use `run_test()` for command-line test selection.

## Top-Level Parameters

The `top` module currently uses:

| Parameter | Value |
|---|---:|
| `ADDR_W` | 32 |
| `DATA_W` | 32 |
| `ID_W` | 4 |
| `USER_W` | 1 |

The simulation clock has a 10-time-unit period. Reset is active low and is released after the first positive clock edge.

## Transaction Constraints

The sequence item applies constraints such as:

- Write and read burst lengths match.
- Write and read burst types match.
- Write and read transfer sizes match.
- Read and write start addresses match.
- Burst length is between 2 and 16 beats.
- WRAP bursts use legal lengths of 2, 4, 8, or 16 beats.
- Transfer size is constrained to 1, 2, or 4 bytes.
- Addresses remain within `MEM_BYTES`.
- Write data is non-zero.
- `WLAST` is asserted on the final write beat.
- Unused AXI sideband fields are driven to zero.

After randomization, the transaction calculates write/read beat addresses and the write strobes for each beat.

## Current Development Notes

- The scoreboard declares write and read analysis FIFOs, but reference-model comparison logic is not yet implemented.
- The driver contains the main outstanding and per-ID response-tracking infrastructure.
- Write and read monitors currently reconstruct transactions sequentially and still need per-ID outstanding-transaction support.
- A dedicated ordering test is still needed to issue controlled ID patterns and prove reordered completions.
- Out-of-order operation is permitted only across different IDs; same-ID transactions must remain ordered.
- `rd_driver` is currently a configuration placeholder; read requests are driven by `wr_driver`.
- The default top-level test is hard-coded as `test`.
- Simulator commands require the actual filenames for the AXI package, interface, DUT, and any RTL dependencies.
- Review the `inc_unalign_seq` size constraint before relying on it: the base item allows sizes `0`, `1`, and `2`, while the sequence also requests `{2,4}`.

## Recommended Next Steps

1. Complete per-ID transaction reconstruction in the write and read monitors.
2. Implement the scoreboard reference memory and write/read comparison logic.
3. Add a dedicated outstanding/out-of-order sequence using controlled AXI IDs.
4. Add functional coverage for outstanding depth, response order, burst type, length, size, alignment, and response.
5. Add protocol assertions for AXI handshakes, stable payloads during stalls, burst completion, and response ordering.
6. Move test selection to `run_test()` for easier regression execution.
7. Add a simulator file list or build script containing the complete source order.
