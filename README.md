# UART with Integrated RAM Storage

Full-duplex, 8N1 UART RTL in Verilog with synchronized receive sampling and actual synchronous byte storage. TX and RX run independently on one system clock.

## Features

- Eight data bits, least-significant bit first, no parity, one stop bit.
- Two-stage receive synchronizer and a start-bit midpoint check to reject short glitches. Synchronization reduces the risk of metastability propagating; it does not eliminate that risk.
- Midpoint data/stop sampling. Invalid stop bits produce a one-clock `framing_error` pulse, preserve the last valid byte, and do not write RAM. A held-low line waits for recovery rather than producing repeated bytes.
- Parameter-derived timer widths, including divisors greater than 16,384.
- Sequential received-byte storage with synchronous readback, integrated into `uart_top`.
- Active-low **synchronous** reset with defined status/data outputs.

## Modules

| File | Role |
| --- | --- |
| `src/uart_tx.v` | Latches a byte on an accepted request and serializes it |
| `src/uart_rx.v` | Synchronizes, samples, and validates incoming frames |
| `src/uart_ram.v` | Stores accepted bytes and provides synchronous readback |
| `src/uart_top.v` | Connects TX, RX, and RAM |
| `sim/uart_top_tb.v` | Self-checking UART and integration regression |
| `sim/uart_ram_tb.v` | Consecutive writes, wraparound, and read/write collision checks |

## Interface and timing

Set `BAUD_DIV` to the integer number of system-clock cycles per serial bit:

```text
BAUD_DIV = clock_frequency / baud_rate
```

The default is **10,416 clock cycles per bit**, approximately 9,600 baud with a 100 MHz clock. TX/RX `TICKS_PER_BIT` parameters have the same units. Supported divisors are at least **8**; simulation rejects smaller values. Check clock rounding and the combined transmitter/receiver clock error for your application.

- Assert `tx_start` for one clock while `tx_busy` is low. `tx_byte` is latched on that rising edge. Requests while busy are ignored; there is no transmit queue.
- `rx_done` pulses for one clock only for a valid frame; `rx_byte` retains the last accepted byte.
- RAM stores the byte on the following rising edge. `ram_we` reports that write for one clock, while `ram_addr` and `ram_data_in` report the address and byte just written.
- Assert `ram_read_en` with `ram_read_addr` before a rising edge. `ram_read_data` updates after that edge and otherwise holds its value. Tie `ram_read_en` low if readback is unused.
- `RAM_ADDR_WIDTH` defaults to 10 (1,024 bytes). The write pointer starts at zero and wraps, overwriting the oldest data. There is no full flag or flow control; the consumer must keep track of valid addresses.
- Reset clears the pointer and output registers but does not clear the memory array. Read only locations written since reset. A simultaneous read/write at the same address returns the old value in this RTL.

The added RAM readback and framing-error ports extend the original top-level interface. Update existing instantiations to connect them. RX has IDLE, START, DATA, STOP, and error RECOVER states; TX uses IDLE, START, DATA, and STOP.

## Run the tests

Install Python 3 and Icarus Verilog, with `iverilog` and `vvp` on PATH. From the repository root:

```sh
python scripts/run_tests.py
```

The script tests divisors 8, 9, 100, and 20,000 and verifies rejection of divisor 7. Tests include TX bit order and duration, busy requests, loopback, independent RX, simultaneous TX/RX, all 256 received byte values at divisor 100, back-to-back frames, approximately +/-2% input bit-period variation at larger divisors, false starts, invalid stops, held-low recovery, reset during a frame, real RAM readback, pointer wrap, and consecutive writes. Failures stop with a nonzero exit code; every simulation has a timeout.

For a waveform of the default test:

```sh
iverilog -g2012 -Wall -s uart_top_tb -o uart_test.vvp src/*.v sim/uart_top_tb.v
vvp uart_test.vvp +vcd
```

Open `uart_top.vcd` in GTKWave. For RTL lint:

```sh
verilator --lint-only -Wall --top-module uart_top src/*.v
```

GitHub Actions runs simulation and RTL lint on pushes and pull requests.

## FPGA use

Use `uart_top` as the synthesis top and supply clock/pin constraints for your board. Match the baud divisor to its oscillator and use suitable external UART voltage levels. The memory is written in a synchronous RAM inference style, without resetting its array; inspect your synthesis report to confirm the implementation on your target device. These checks are simulation and lint verification, not a claim of hardware validation or timing closure.
