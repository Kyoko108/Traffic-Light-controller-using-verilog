# Verification Notes — Traffic Light Controller

## What this adds
A self-checking verification testbench on top of the existing
`traffic_light.v` design and basic `traffic_light_tb.v`:

- **Safety checks**: mutual exclusion (never more than one light on),
  reset behavior, output-to-state consistency.
- **Liveness/ordering checks**: exact state durations (RED=10, GREEN=10,
  YELLOW=3 cycles) and that transitions only ever follow the legal
  RED→GREEN→YELLOW→RED sequence.
- **Directed + randomized reset injection**: reset is forced at known
  offsets inside each state (directed corners) and at pseudo-random
  points (8 additional draws), checking recovery to RED from any state.
- **Functional coverage** (manual bins, since Icarus Verilog has no
  native `covergroup` support): tracks which states were exercised and
  whether reset was tested from all three states, with a printed report.

## Scope, honestly
This is **not** UVM. For a 3-state, 2-output FSM, a class-based
UVM environment (driver/monitor/sequencer/scoreboard) would be
architectural overkill. What's here — self-checking assertions,
directed+random stimulus, and coverage tracking — is the part that
actually matters and is genuinely uncommon at undergrad level.

Concurrent SystemVerilog assertions (`property`/`assert property` with
a clocking event) are **not supported by this Icarus Verilog build**
(verified directly — a minimal isolated test throws a syntax error).
Every check here is written as a procedural immediate assertion
instead, with the equivalent formal SVA `property` given as a comment
above each checker for reference. If you get access to Questa/VCS/
Xcelium, or a newer Icarus/Verilator, converting these to real
concurrent assertions and `covergroup`s is a natural next step.

## Bugs found and fixed while building this (kept as a record —
this is more valuable in an interview than a testbench that "just worked")

1. **Testbench sampling race**: checkers originally sampled outputs on
   `posedge clk`, the same edge the DUT's own sequential block updates
   on. Fixed by sampling on `negedge clk` instead.
2. **Broken tool primitives**: this Icarus Verilog build's
   `$countones`/`$onehot0` returned garbage on a 3-bit concatenation —
   confirmed with an isolated 5-line test before assuming it was a DUT
   bug. Replaced with manual bit counting.
3. **Verilog width trutruncation**: naively summing 1-bit signals
   (`red + yellow + green`) silently truncates to 1-bit result width
   (1+1 = 0, not 2). Fixed by casting each operand to `int` first.
4. **Stimulus race**: `rst` was driven with a *blocking* assignment
   immediately after `@(posedge clk)`, racing the DUT's own read of
   `rst` on that identical edge — this shifted the RED duration by
   exactly one cycle. Fixed by driving `rst` with nonblocking
   assignment, which guarantees the DUT samples the old value on the
   edge you change it.
5. **Coverage sampling gap (not a race, a logic error)**: the "reset
   during GREEN/YELLOW" coverage bins never hit because the state was
   sampled *after* reset had already forced it back to RED. Fixed by
   sampling the tracked `prev_state` (the state as it was the cycle
   before reset hit) instead.

## Run it
```
iverilog -g2012 -gassertions -o tlc_tb.vvp traffic_light.v traffic_light_verif_tb.sv
vvp tlc_tb.vvp
```
Expected: `RESULT: PASS -- all safety/liveness/ordering checks held, all coverage bins hit`

Output obtained at  terminal : 
<img width="611" height="230" alt="Screenshot 2026-07-23 123453" src="https://github.com/user-attachments/assets/11dd4e69-5c80-4a13-8e98-c5f6f7576670" />

