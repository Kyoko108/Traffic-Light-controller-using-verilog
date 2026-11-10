<div align = "center">

# Traffic Light Controller using Verilog

FSM-based traffic light controller in Verilog HDL, with a self-checking SystemVerilog testbench. Simulated with Icarus Verilog.

</div>

---

## Design

Three-process FSM (state register, next-state logic, output logic) cycling RED → GREEN → YELLOW → RED.

| State  | Duration        |
| ------ | --------------- |
| RED    | 10 Clock Cycles |
| GREEN  | 10 Clock Cycles |
| YELLOW | 3 Clock Cycles  |

* **Reset:** TODO (sync or async, active-high or low, which state it resets to)
* **Outputs:** TODO (registered or combinational, encoding of red/green/yellow)
* **State encoding:** TODO (binary or one-hot, as coded)

<div align = "center" >
<img width="460" height="460" alt="image" src="https://github.com/user-attachments/assets/2cbeb4ef-b216-4af4-b323-29ee96de01f1" />
<p><strong>State Diagram for this particular Traffic Controller FSM </strong></p>
</div>

---

## Files

| File                      | Description                                                |
| ------------------------- | ---------------------------------------------------------- |
| traffic_light.v           | Verilog RTL implementation of the Traffic Light Controller |
| traffic_light_tb.v        | Basic testbench (log/waveform inspection)                  |
| traffic_light_verif_tb.sv | Self-checking testbench with coverage                      |
| VERIFICATION_NOTES.md     | Scope, limitations, bugs found                             |
| Makefile                  | `make sim`, `make verify`, `make clean`                    |

---

## Run

Requires [Icarus Verilog](https://github.com/steveicarus/iverilog) and `make`.

```
make sim      # basic testbench
make verify   # self-checking testbench
```

### Basic simulation output

<div align ="center" >
<img width="826" height="165" alt="608385835-78c70d6b-bc8e-42a4-b412-23339293b99e" src="https://github.com/user-attachments/assets/e5f9005b-a5d7-4288-bb04-a06a1370c9fe" />
<p><strong>Output of our Traffic Controller FSM </strong></p>
</div>

### Verification output

Expected result from `make verify`: `RESULT: PASS -- all safety/liveness/ordering checks held, all coverage bins hit`

<div align="center">
 <img width="619" height="227" alt="Screenshot 2026-07-23 130218" src="https://github.com/user-attachments/assets/1c5fd5b0-1591-4683-ac17-d3d9419770de" />
<p><strong>Verification testbench output: all safety/liveness/ordering checks passed, all coverage bins hit</strong></p>
</div>

---

## What this verifies

`traffic_light_verif_tb.sv` is self-checking, not simulate-and-eyeball-the-waveform:

* **Safety:** never more than one light on at once; correct outputs after reset; outputs consistent with the current state
* **Timing:** RED = 10, GREEN = 10, YELLOW = 3 cycles, exactly
* **Sequencing:** only RED → GREEN → YELLOW → RED transitions occur
* **Reset recovery:** directed and randomized reset injection, checking recovery to RED from any state
* **Coverage:** manual bins with a printed report (the Icarus Verilog build used here has no native `covergroup` support)

### Bugs found while building it

* Testbench sampling race: TODO (one line: symptom and fix)
* Broken tool primitive mistaken for a DUT bug: TODO (one line: what it was and how the DUT was ruled out)

Full scope notes and limitations are in [VERIFICATION_NOTES.md](VERIFICATION_NOTES.md).

---

## Limitations

* Fixed timing, no parameterization
* Single signal only, no sensor or pedestrian input
* Not yet synthesized: TODO (replace with synthesis results once done)
