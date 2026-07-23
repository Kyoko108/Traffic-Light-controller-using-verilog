<div align = "center">
# Traffic Light Controller using Verilog
</div>

## Overview

This project implements a finite state machine (FSM)-based Traffic Light Controller in Verilog HDL. The controller cycles through three traffic light states:

* RED
* GREEN
* YELLOW

The design follows the standard three-process FSM architecture:

1. State Register
2. Next-State Logic
3. Output Logic

This approach improves readability, modularity, and synthesizability, making it suitable for digital design and VLSI learning.

---

## State Timing

| State  | Duration        |
| ------ | --------------- |
| RED    | 10 Clock Cycles |
| GREEN  | 10 Clock Cycles |
| YELLOW | 3 Clock Cycles  |

The sequence repeats indefinitely:

RED → GREEN → YELLOW → RED

---

## Files

| File               | Description                                                |
| ------------------ | ---------------------------------------------------------- |
| traffic_light.v    | Verilog RTL implementation of the Traffic Light Controller |
| traffic_light_tb.v | Testbench used for simulation and verification             |

---

## FSM State Diagram

<div align = "center" >
<img width="460" height="460" alt="image" src="https://github.com/user-attachments/assets/2cbeb4ef-b216-4af4-b323-29ee96de01f1" />
<p><strong>State Diagram for this particular Traffic Controller FSM </strong></p>
</div>

---

## Verification
 
In addition to the basic testbench above, this repo includes a self-checking
verification environment (`traffic_light_verif_tb.sv`) that goes beyond
simulate-and-eyeball-the-waveform:
 
- Safety checks: mutual exclusion (never more than one light on at once),
  reset behavior, output-to-state consistency
- Liveness/ordering checks: exact state durations (RED=10, GREEN=10,
  YELLOW=3 cycles) and legal RED→GREEN→YELLOW→RED sequencing only
- Directed + randomized reset injection, checking recovery to RED from any state
- Functional coverage tracking (manual bins, since this toolchain's Icarus
  Verilog build has no native `covergroup` support), with a printed report
Full scope notes, limitations, and a record of bugs found while building
this (including a testbench sampling race and a broken tool primitive
caught before being mistaken for a DUT bug) are documented in
[VERIFICATION_NOTES.md](VERIFICATION_NOTES.md).
 
### Run it
 
```
iverilog -g2012 -gassertions -o tlc_tb.vvp traffic_light.v traffic_light_verif_tb.sv
vvp tlc_tb.vvp
```
 
### Verification Output
Expected result: `RESULT: PASS -- all safety/liveness/ordering checks held, all coverage bins hit` 

<div align="center">
 <img width="619" height="227" alt="Screenshot 2026-07-23 130218" src="https://github.com/user-attachments/assets/1c5fd5b0-1591-4683-ac17-d3d9419770de" />
<p><strong>Verification testbench output: all safety/liveness/ordering checks passed, all coverage bins hit</strong></p>
</div>


 ---
 

## Simulation

The design was simulated using Icarus Verilog.

### Compilation

```cmd
iverilog -o traffic.exe traffic_light.v traffic_light_tb.v
```

### Execution

```cmd
vvp traffic.exe
```

---

## Below is the Output

<div align ="center" >
<img width="826" height="165" alt="608385835-78c70d6b-bc8e-42a4-b412-23339293b99e" src="https://github.com/user-attachments/assets/e5f9005b-a5d7-4288-bb04-a06a1370c9fe" />
<p><strong>Output of our Traffic Controller FSM </strong></p>
</div>

---

## Learning Objectives

* Finite State Machine (FSM) Design
* Verilog HDL Coding
* Combinational and Sequential Logic Separation
* Testbench Development
* Functional Verification using Simulation

---
