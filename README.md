# APB Protocol — Verilog Implementation

## Overview

This project implements an **AMBA APB (Advanced Peripheral Bus) Protocol** in Verilog. The design consists of a single APB master 
communicating with two RAM-based slaves. Slave selection is based on the most significant bit (bit[8]) of the address i.e 9th bit. 
The entire design is parameterized for data width and address width.

## Module Descriptions

### 1. `apb_protocol` (Top Module)

The top-level wrapper that instantiates the master and both slaves, and connects all internal APB bus signals.

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `PCLK` | Input | 1 | System clock (rising edge triggered) |
| `PRESETn` | Input | 1 | Active-low asynchronous reset |
| `transfer` | Input | 1 | Initiates an APB transfer when high |
| `READ_WRITE` | Input | 1 | 1 = Write, 0 = Read |
| `apb_write_paddr` | Input | 9 | Write address (bit[8] selects slave) |
| `apb_write_data` | Input | 8 | Data to write |
| `apb_read_paddr` | Input | 9 | Read address (bit[8] selects slave) |
| `apb_read_data_out` | Output | 8 | Data read from selected slave |

---

### 2. `master`

Implements the APB master FSM with three states: IDLE, SETUP, and ACCESS. Controls all APB bus signals and handles slave selection, read data capture, and back-to-back transfers.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 8 | Width of data bus |
| `ADDRESS_WIDTH` | 9 | Width of address bus (MSB used for slave select) |

**Key Ports:**

| Port | Direction | Description |
|------|-----------|-------------|
| `PSEL1` / `PSEL2` | Output | Slave select signals (active high) |
| `PENABLE` | Output | Enables the ACCESS phase (active high) |
| `PADDR[7:0]` | Output | Address to slave (MSB stripped) |
| `PWRITE` | Output | 1 = Write, 0 = Read |
| `PWDATA` | Output | Write data to slave |
| `PRDATA1/2` | Input | Read data from slave 1 / slave 2 |
| `PREADY1/2` | Input | Ready signal from slave 1 / slave 2 |

---

### 3. `apb_slave`

A RAM-based APB slave. Each slave contains a 256-entry memory. Write and read operations are performed during the ACCESS phase when both `PSEL` and `PENABLE` are asserted.

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 8 | Width of data bus |
| `ADDRESS_WIDTH` | 9 | Width of address bus |

**Key Ports:**

| Port | Direction | Description |
|------|-----------|-------------|
| `PSEL` | Input | Slave select (active high) |
| `PENABLE` | Input | Transfer enable (active high) |
| `PWRITE` | Input | Write enable |
| `PADDR[7:0]` | Input | Memory address |
| `PWDATA` | Input | Write data |
| `PRDATA` | Output | Read data |
| `PREADY` | Output | Slave ready (asserted for one cycle on ACCESS) |

---

## FSM — APB Master State Machine

```
         PRESETn=0
             │
             ▼
          ┌──────┐
          │ IDLE |◄──────────────────────────┐
          │PSEL=0│                           │
          │PEN=0 │                           │ PREADY=1
          └──┬───┘                           │ transfer=0
            │ transfer=1                    │
            ▼                               │
          ┌───────┐                       ┌──┴──────┐
          │ SETUP │──────────────────────►│ ACCESS  │
    | ──► │PSEL=1 │   always 1 cycle      │ PSEL=1  │◄┐
    |     │PEN=0  │                       │ PEN=1   │  │ PREADY=0
    │     └───────┘                       └─────────┘  │
    │                                          │  │  ──   
    └──────────────────────────────────────────┘        
              PREADY=1, transfer=1                       
              (go to SETUP for next transfer)            
```

**State Outputs:**

| State | PSELx | PENABLE | Description |
|-------|-------|---------|-------------|
| IDLE | 0 | 0 | Bus idle, waiting for transfer |
| SETUP | 1 | 0 | Address/data presented, one cycle only |
| ACCESS | 1 | 1 | Active transfer, slave performs read/write |

---

## Slave Selection

The MSB (bit[8]) of the address determines which slave is selected:

| bit[8] | Selected Slave | Address Range |
|--------|---------------|---------------|
| 0 | Slave 1 | `0x000` – `0x0FF` |
| 1 | Slave 2 | `0x100` – `0x1FF` |

The lower 8 bits `[7:0]` are passed to the slave as the memory address.

---

## Signal Priority (per spec)

1. `PRESETn` — active low, highest priority
2. `PSEL` — active high
3. `PENABLE` — active high
4. `PREADY` — active high
5. `PWRITE`

---

## Testbench — `tb_apb_protocol`

The testbench is self-checking and uses `$display` to report PASS/FAIL for each test.

**Test Cases:**

| Test | Description |
|------|-------------|
| 1 | Single write to Slave 1 |
| 2 | Single read from Slave 1 |
| 3 | Write-read self-check on Slave 1 (3 addresses) |
| 4 | Single write to Slave 2 |
| 5 | Single read from Slave 2 |
| 6 | Write-read self-check on Slave 2 |
| 7 | Reset during operation — verify output clears |
| 8 | Multiple sequential address writes on Slave 1 |
| 9 | IDLE hold — transfer=0, verify bus stays idle |
| 10 | Boundary address check (0x0FF and 0x1FF) |

**Expected Console Output (passing):**
```
------------------------------------------------
  APB Protocol Testbench
------------------------------------------------
[WRITE] addr=0x10  data=0xab  time=...
[READ]  addr=0x10  data=0xab  time=...
[PASS]  addr=0x5   expected=0x55  got=0x55
...
[PASS]  Reset cleared output correctly
...
  All Tests Complete
------------------------------------------------
```

---

## Simulation

**Using VCS:**
```bash
vcs -sverilog master.v apb_slave.v apb_protocol.v tb_apb_protocol.v -o simv
./simv
```

**Using Icarus Verilog:**
```bash
iverilog -o sim.out master.v apb_slave.v apb_protocol.v tb_apb_protocol.v
vvp sim.out
```

**View waveforms (GTKWave):**
```bash
gtkwave tb_apb_protocol.vcd
```

---

## Design Notes

- All signals are captured on the **rising edge** of `PCLK`.
- `PRESETn` is **active low** and asynchronous.
- The APB bus is **enabled only when `transfer` is high**; otherwise it stays in IDLE.
- `PADDR`, `PWRITE`, and `PWDATA` must remain **stable** from SETUP through ACCESS (per APB spec).
- Back-to-back transfers are supported: when `PREADY=1` and `transfer` is still high, the FSM goes directly from ACCESS back to SETUP.
- Each slave has an independent 256×8 memory bank.

---

## Parameters

Both `DATA_WIDTH` and `ADDRESS_WIDTH` are parameterized at every level (top, master, slave) and passed via `#()` overrides. To change to 32-bit data and 10-bit address:

```verilog
apb_protocol #(.DATA_WIDTH(32), .ADDRESS_WIDTH(10)) dut ( ... );
```

---

## Author

Ateef Baig \
RTL Intern
