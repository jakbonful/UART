# UART Transceiver — Verilog RTL

A fully parameterized, simulation-verified UART transceiver implemented in Verilog, targeting the Basys 3 (Artix-7 FPGA). The design uses 16× oversampling on the receiver for robust bit-centre sampling, and passes an 8-byte loopback test suite covering boundary patterns, alternating bit patterns, and typical data values.

---

## Project Structure

```
UART/
├── rtl/
│   ├── baudrate_gen.v      # Parameterized baud rate generator
│   ├── uart_tx.v           # UART transmitter FSM
│   ├── uart_rx.v           # UART receiver FSM (16× oversampling)
│   └── uart_top.v          # Top-level integration
├── tb/
│   ├── tb_baudrate.v       # Baud rate generator unit testbench
│   ├── tb_uart_rx.v        # Receiver unit testbench
│   ├── tb_uart_tx.v        # Transmitter unit testbench
│   └── tb_uart_top.v       # Full loopback testbench
├── sim/
│   ├── modelsim/           # ModelSim working library
│   ├── scripts/
│   │   └── run.do          # ModelSim simulation script
│   └── waveforms/
│       ├── UART_results.png
│       ├── UART_simulation.png
│       ├── UART_synthesis.png
│       └── UART_waveform.png
├── synth/
│   └── vivado/             # Vivado project files and reports
├── .gitignore
└── README.md
```

---

## Architecture

### Top Level

```
                  ┌─────────────────────────────────────────┐
                  │              uart_top                    │
  clk, rst_n ────►│                                         │
  data_in  ──────►│  BRG_TX ──► Transmitter ──┐            │
  start    ──────►│  (115200 Hz)               │            │
                  │                       serial_line       │
                  │  BRG_RX ──► Receiver ◄──┘             │
                  │  (1.8432 MHz)              │            │
                  │                       data_out ────────►│
                  │                       rx_valid ─────────│►
                  └─────────────────────────────────────────┘
```

The top level instantiates two independent baud rate generators — one running at the baud rate for the transmitter, and one running at 16× the baud rate for the receiver's oversampling counter. The serial line connects TX output directly to RX input for loopback.

### Baud Rate Generator (`baudrate_gen.v`)

A simple counter that asserts `baud_tick` for one clock cycle every `CLK_FREQ / BAUD_RATE` cycles. Both divisors are computed from the same two parameters at elaboration time via `localparam`, so changing the target baud rate or clock frequency requires editing only the top-level instantiation.

| Parameter  | Default        |
|------------|----------------|
| `CLK_FREQ` | 50,000,000 Hz  |
| `BAUD_RATE`| 115,200 baud   |

### Transmitter (`uart_tx.v`)

A four-state Mealy FSM:

```
IDLE ──(tx_start)──► START ──(baud_tick)──► DATA ──(bit_index==7 & baud_tick)──► STOP ──(baud_tick)──► IDLE
```

The data byte is latched into a shift register on entry to START. `tx_out` is driven combinatorially from the current state and `shift_reg[bit_index]`, keeping output glitch-free. The bit index increments on each `baud_tick` in the DATA state.

### Receiver (`uart_rx.v`)

A four-state FSM with 16× oversampling:

```
IDLE ──(falling edge)──► START ──(counter==15)──► DATA ──(bit_index==7 & sample)──► STOP ──(sample)──► IDLE
```

Key implementation points:

- **False-start rejection** — the receiver samples the line at the midpoint of the START bit (counter = 8). If `rx_in` is still high, it returns to IDLE, ignoring the glitch.
- **Bit-centre sampling** — a `sample_point` is defined as `counter == 8`, placing the sample at the midpoint of each data bit period for maximum noise margin.
- **Edge detection** — a pipeline register (`rx_in_prev`) generates a one-cycle `falling_edge` pulse, triggering START detection without level sensitivity.
- **rx_valid** — registered as a one-cycle pulse one clock after the STOP sample, giving downstream logic a clean strobe.

---

## Simulation

### Tool

ModelSim (Questa) via `run.do` script.

### Testbench Strategy

The testbench drives the top-level `start_signal` with 8 test vectors covering a range of bit patterns, then captures `data_out` when `rx_valid` is asserted. Each vector is sent sequentially with an inter-frame gap between frames. Results are compared against expected values and reported in a summary table.

### Test Vectors

| Test | Data     | Pattern              |
|------|----------|----------------------|
| 1    | `0xAD`   | Mixed                |
| 2    | `0x55`   | Alternating (01...)  |
| 3    | `0xAA`   | Alternating (10...)  |
| 4    | `0xFF`   | All ones             |
| 5    | `0x00`   | All zeros            |
| 6    | `0x01`   | LSB only             |
| 7    | `0x80`   | MSB only             |
| 8    | `0xA5`   | Mixed                |

### Result

```
=== RECEIVED DATA SUMMARY ===
Test 1 : expected = 8'had, captured = 8'had
Test 2 : expected = 8'h55, captured = 8'h55
Test 3 : expected = 8'haa, captured = 8'haa
Test 4 : expected = 8'hff, captured = 8'hff
Test 5 : expected = 8'h00, captured = 8'h00
Test 6 : expected = 8'h01, captured = 8'h01
Test 7 : expected = 8'h80, captured = 8'h80
Test 8 : expected = 8'ha5, captured = 8'ha5
=============================

ALL LOOPBACK TESTS PASSED
```

### Waveforms

Captured waveforms from the ModelSim simulation are in `sim/waveforms/`:

| File                    | Contents                                      |
|-------------------------|-----------------------------------------------|
| `UART_waveform.png`     | Full signal trace across a single UART frame  |
| `UART_simulation.png`   | Multi-frame loopback simulation overview      |
| `UART_results.png`      | Transcript showing all 8 tests passing        |
| `UART_synthesis.png`    | Elaborated design schematic from Vivado       |

### Running the Simulation

```tcl
# From the ModelSim transcript, or via the run.do script:
vlib work
vmap work work
vlog rtl/baudrate_gen.v rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v tb/tb_uart_top.v
vsim work.tb_uart_top
add wave -position end sim:/tb_uart_top/*
run -all
```

---

## Synthesis (Vivado 2025.2 — Artix-7)

Target device: `xc7a35tcpg236-1` (Basys 3).

The design elaborates and synthesizes without errors or timing violations at 115200 baud. The elaborated schematic shows the two baud rate generator counters, the transmitter FSM, and the receiver FSM with its oversampling counter as clearly distinct logic cones.

> Synthesis resource utilization and timing reports are in `synth/vivado/`. The elaborated schematic screenshot is at `sim/waveforms/UART_synthesis.png`.

---

## Parameters

All key parameters are exposed at the `uart_top` level and propagate through to submodules:

| Parameter    | Description                        | Default    |
|--------------|------------------------------------|------------|
| `CLK_FREQ`   | System clock frequency (Hz)        | 50,000,000 |
| `BAUD_RATE`  | Target baud rate                   | 115,200    |
| `OVERSAMPLE` | RX oversampling ratio              | 16         |

Changing `CLK_FREQ` or `BAUD_RATE` at the top-level instantiation is sufficient to retarget the design.

---

## Design Decisions

**Why 16× oversampling?** It is the standard choice for UART receivers: it provides 8-cycle timing margin on either side of the sample point, tolerating reasonable clock drift between transmitter and receiver without requiring a PLL.

**Why one-hot state encoding?** The four FSM states are each assigned a unique bit, making state decode logic trivially cheap on FPGA LUTs and simplifying waveform debugging — the state register value directly identifies which state is active.

**Why a registered rx_valid?** Deriving `rx_valid` directly from combinatorial state comparison would create a pulse whose width depends on counter timing. Registering it as `(state == STOP && sample_point)` on the clock edge produces a clean one-cycle pulse aligned to the system clock, which is safe to use as a data strobe downstream.

---

## Tools

| Tool            | Version     | Purpose                        |
|-----------------|-------------|--------------------------------|
| ModelSim/Questa | —           | RTL simulation                 |
| Vivado          | 2025.2      | Synthesis, schematic, reports  |
| VS Code         | —           | HDL editing                    |
| GitHub          | —           | Version control                |

---

## Author

John Bonful  
BSc Electrical/Electronic Engineering, KNUST  
[github.com/jakbonful](https://github.com/jakbonful) · [linkedin.com/in/johnbonful](https://linkedin.com/in/johnbonful)
