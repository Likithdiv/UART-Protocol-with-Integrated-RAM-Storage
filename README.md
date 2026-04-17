## Project Overview
This project implements a full-duplex UART communication system. It is designed to handle asynchronous serial data transfer with high reliability by incorporating hardware-level synchronization and optimized sampling logic.

### Key Features
Anti-Metastability: Dual-stage synchronizer on the rx_line to ensure stable data sampling.

Robust Sampling: Implements middle-of-the-bit sampling ($TICKS/2$) to maximize setup/hold time margins and provide false-start bit protection.

Modular Memory Interface: Includes a uart_ram module that automatically stores received bytes into sequential memory addresses.

Configurable Baud Rate: Parameterized design allowing easy adjustment for different clock frequencies (default set for 10416 ticks, e.g., 9600 Baud at 100MHz).

## Technical Specifications
### UART Frame Format
Baud Rate: Configurable via TICKS_PER_BIT (Default: 9600)
Data Width: 8 bits
Parity : none

### Finite State Machine (FSM) Logic

Both TX and RX modules utilize a 4-state Mealy/Moore hybrid FSM:

IDLE: Waiting for tx_start (TX) or a falling edge on rx (RX).
START: Timing the duration of the Start bit.
DATA: Iterating through 8 bits of data using a bit_idx pointer.
STOP: Validating the stop bit and asserting status flags (tx_busy or rx_done).

## Design Highlights for RTL Interviewers
### 1. Clock Domain Crossing (CDC) Protection
// Anti-metastability synchronizer logic used in uart_rx
always @(posedge clk) begin
    rx_sync1 <= rx;      // First Stage
    rx_sync2 <= rx_sync1; // Second Stage (Stable Output)
end

By passing the asynchronous rx input through two flip-flops, the design significantly reduces the Probability of Metastability (MTBF), ensuring the FSM doesn't enter an invalid state.

### 2. Precision Sampling
The receiver doesn't sample immediately upon detecting a low signal. It waits for $TICKS\_PER\_BIT / 2$ to ensure the signal has settled and to verify it isn't just a noise glitch (False Start Bit Protection)

## How to Use

Simulation: Load the files into Vivado, Questa, or Icarus Verilog.
Synthesize: Set uart_top as the top module.
Parameters: Adjust BAUD_DIV in uart_top based on your FPGA's oscillator frequency
$$TICKS\_PER\_BIT = \frac{Clock\_Frequency}{Baud\_Rate}$$
