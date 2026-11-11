# Verification Notes — Traffic Light Controller

Tested with Icarus Verilog 12.0 (stable), `-g2012`.

## What the testbench does

`traffic_light_verif_tb.sv` checks `traffic_light.v` through its three output pins only, plus one fault-injection hook.

- **Reference model:** a position counter `0..22` (modulo the 23-cycle sequence), reset by `rst`. Expected pins are derived from the position: `0-9` RED, `10-19` GREEN, `20-22` YELLOW. It is a different formulation from the DUT's state machine, so it does not share its mistakes.
- **Scoreboard:** sampled on `negedge clk`. Checks pins against the model, exactly one light on, and no X/Z.
- **Reset:** async assert mid-cycle at all 23 positions (RED required 1 ns later, with no clock edge in between); edge-timed resets at positions 1-22; random pulses from 1 ns runts to multi-cycle.
- **Fault injection:** `force`/`release` on `dut.state` with `000`, `011`, `101`, `110`, `111`. The model is resynchronized for the recovery edge, then the scoreboard resumes.
- **Randomness:** 60 events, driven by `$random(seed)`. The seed is printed and settable with `+SEED=n`.
- **Coverage:** reset-arrival position (23 bins), illegal-code recovery (5), async reset from a non-RED state, uninterrupted sequence wraps. The reset position is sampled from a copy of the model position delayed by 1 ns (`pos_d`), because sampling `pos` directly depends on the ordering of nonblocking updates when reset changes on a clock edge. Any empty bin fails the run.
- **Result gate:** prints `RESULT: PASS` or `RESULT: FAIL`. `vvp` itself always exits 0, so the Makefile greps the log and fails the target if `PASS` is missing.

## Mutation testing

`mutate.py` patches 13 bugs into the RTL one at a time, rebuilds, and requires `RESULT: FAIL` for each. It first checks that the unmodified RTL passes, and asserts that every patch pattern is found, so a mutant cannot silently fail to apply.

| # | Mutant |
|---|--------|
| 1 | RED lasts 11 cycles |
| 2 | YELLOW lasts 4 cycles |
| 3 | GREEN lasts 9 cycles |
| 4 | GREEN skips YELLOW |
| 5 | Illegal state locks up (default holds state) |
| 6 | Illegal state `000` not recovered |
| 7 | Reset is synchronous |
| 8 | Reset ignored on the terminal-count cycle |
| 9 | Counter not cleared on state change |
| 10 | Counter kept through GREEN |
| 11 | Reset leaves counter at 5 |
| 12 | Counter too narrow (3 bits) |
| 13 | Green/yellow outputs swapped |

Result: 13 / 13 caught. Mutants 5, 6, 7 and 8 are caught only by the reset and injection phases, not by the free-running check. With the directed boundary resets removed, random resets alone missed mutant 8 on 1 of 5 seeds.

Limit: the mutants were written by the same person who wrote the testbench, so this shows the testbench catches those 13 bugs, not every bug.

## Scope

This is not UVM. A class-based environment would add structure without adding checking power for a 3-state FSM.

Concurrent SystemVerilog assertions are not available: Icarus 12.0 reports a syntax error on `assert property`, with or without `-gassertions`. All checks are procedural. If Questa/VCS/Xcelium, a newer Verilator, or SymbiYosys becomes available, mutual exclusion and bounded duration are natural candidates for assertions or a formal proof.

## Tool issues (Icarus 12.0)

`$countones` and `$onehot`/`$onehot0` return wrong values on a packed 3-bit concatenation. Repro:

```systemverilog
module t; logic r, y, g;
  initial begin
    r=1; y=0; g=0;
    $display("%0d %b %b", $countones({r,y,g}), $onehot0({r,y,g}), $onehot({r,y,g}));
  end
endmodule
```

Observed: `6 0 0`. Expected `1 1 1`. For `{r,y,g} = 000` it returns a count of 4. The testbench sums the bits manually.

Width pitfall: `r + y` on 1-bit operands truncates to 1 bit in a self-determined context (a `$display` argument or a 1-bit variable), so 1 + 1 gives 0. In a comparison with a 32-bit literal (`(r+y+g) != 1`) it does not truncate. The testbench casts each term to `int`.

## Bugs and pitfalls found

Testbench side:

1. **Sampling race:** checkers that sample on `posedge clk` race the DUT's own update on that edge. Fixed by sampling on `negedge clk`.
2. **Stimulus race:** `rst` driven with a blocking assignment right after `@(posedge clk)` races the DUT's read of `rst` on that edge, shifting the RED duration by one cycle. Fixed by driving `rst` with a nonblocking assignment when it changes on a clock edge. Mid-cycle async changes use blocking assignments at times ≥ 2 ns from any edge.
3. **Simulator bug:** `$countones`/`$onehot0` (above), ruled out as a DUT bug with the isolated test.
4. **Width truncation:** (above).
5. **Invalid mutants:** the first two mutants edited RTL parameter defaults, which the testbench overrides at instantiation, so they changed nothing and looked "missed". Mutants now edit the logic.
6. **Time-zero X:** a mutant whose reset condition depended on `done` died on an X at time 0, never reaching the boundary tests. Fixed with `done !== 1'b1`.
7. **Hardcoded report line:** the coverage report printed a fixed "5 / 5" instead of the measured count. It now reports the measured count.
8. **Icarus `force` limitation:** `force` with a non-constant right-hand side only evaluates once and prints a warning. The testbench forces literal values.

Design side (found in review, fixed in the current RTL):

1. **Illegal-state lockup:** state `2'b11` had no exit except reset, with all lights off. Every `case` now has a `default` that returns to RED.
2. **Output glitch risk:** binary state encoding with a combinational decode flipped two bits on GREEN → YELLOW. Replaced by one-hot encoding with outputs wired straight from state flops.
3. **Duplicated terminal count:** the 9 / 9 / 2 terminal counts appeared in two processes. Now computed once and shared.
4. **Hardcoded durations:** replaced by parameters.

## Run it

```
make verify              # self-checking testbench, SEED=1
make verify SEED=42      # different random seed
make mutate              # 13 injected bugs
```

or directly:

```
iverilog -g2012 -o tlc_tb.vvp traffic_light.v traffic_light_verif_tb.sv
vvp tlc_tb.vvp +SEED=1
```

Expected: `RESULT: PASS`.
