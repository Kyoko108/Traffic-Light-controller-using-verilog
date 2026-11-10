<div align = "center">

# Traffic Light Controller using Verilog

FSM-based traffic light controller in Verilog HDL, with a self-checking SystemVerilog testbench. Simulated with Icarus Verilog.

</div>

---

## Design

FSM with a 4-bit cycle counter, cycling RED → GREEN → YELLOW → RED. One clocked process holds the state register and the counter; next-state logic and output logic are separate combinational processes.

| State  | Duration        |
| ------ | --------------- |
| RED    | 10 Clock Cycles |
| GREEN  | 10 Clock Cycles |
| YELLOW | 3 Clock Cycles  |

* **Reset:** Asynchronous, active-high (`posedge rst`). Forces state to RED and counter to 0. Reset deassertion is not synchronized to `clk`.
* **Outputs:** Moore, combinational decode of `current_state` (not registered). One output per light: `red`, `yellow`, `green`.
* **State encoding:** 2-bit binary (RED=`2'b00`, GREEN=`2'b01`, YELLOW=`2'b10`, `2'b11` unused). A 4-bit counter counts 0-9 in RED and GREEN, 0-2 in YELLOW.


<div align = "center" >
<img width="460" height="460" alt="image" src="https://github.com/user-attachments/assets/2cbeb4ef-b216-4af4-b323-29ee96de01f1" />
<p><strong>State Diagram for this particular Traffic Controller FSM </strong></p>
</div>

---

## Files

| File                      | Description                                                                        |
| ------------------------- | -----------------------------------------------------------------------------------|
| traffic_light.v           | Verilog RTL implementation of the Traffic Light Controller                         |
| traffic_light_tb.v        | Basic testbench (prints light changes with `$monitor`; no checks, no waveform dump)|
| traffic_light_verif_tb.sv | Self-checking testbench with coverage                                              |
| VERIFICATION_NOTES.md     | Scope, limitations, bugs found                                                     |
| Makefile                  | `make sim`, `make verify`, `make clean`                                            |

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
* **Timing:** RED = 10, GREEN = 10, YELLOW = 3 cycles, exactly for each completed state run
* **Sequencing:** only RED → GREEN → YELLOW → RED transitions occur
* **Reset recovery:** directed and randomized reset injection, checking recovery to RED from any state
* **Coverage:** manual bins with a printed report (the Icarus Verilog build used here has no native `covergroup` support)

### Bugs found while building it

* Testbench sampling race: `rst` was driven with a blocking assignment, racing the DUT's `@(posedge clk or posedge rst)` block on the edge it changed. The symptom was an off-by-one in the RED duration check. Fixed by driving `rst` with nonblocking assignments.
* Simulator bug mistaken for a DUT bug: Icarus Verilog 12.0 returned wrong values from `$countones`/`$onehot0` on the packed `{red, yellow, green}`, which looked like a mutual-exclusion violation. Confirmed with an isolated test and replaced with a manual bit count.
* Broken tool primitive mistaken for a DUT bug: TODO (one line: what it was and how the DUT was ruled out)

Full scope notes and limitations are in [VERIFICATION_NOTES.md](VERIFICATION_NOTES.md).

---

## Limitations

* No `default` branch in the counter or next-state `case`: if the FSM ever enters the unused encoding `2'b11`, it stays there with all lights off until reset
* Reset deassertion is asynchronous (no reset synchronizer)
* Outputs are decoded combinationally from state, not registered, so they can glitch
* The testbench reads `dut.current_state` hierarchically, so it is tied to this RTL's internal naming and encoding
* The duration checker only checks completed state runs, so a state that never exits is caught only indirectly through coverage
* Fixed timing, no parameterization
* Single signal only, no sensor or pedestrian input
* Not yet synthesized: TODO (replace with synthesis results once done)
