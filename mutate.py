#!/usr/bin/env python3
"""Mutation test: inject known bugs into traffic_light.v and confirm the
self-checking testbench reports RESULT: FAIL for every one.
Usage: python3 mutate.py        (needs iverilog/vvp on PATH)"""
import subprocess, tempfile, os, sys

RTL, TB = "traffic_light.v", "traffic_light_verif_tb.sv"
src = open(RTL).read()

MUTANTS = [
 ("RED lasts 11 cycles",              "default:  last_count = RED_LAST[CNT_W-1:0];", "default:  last_count = RED_LAST[CNT_W-1:0] + 1'b1;"),
 ("YELLOW lasts 4 cycles",            "S_YELLOW: last_count = YELLOW_LAST[CNT_W-1:0];", "S_YELLOW: last_count = YELLOW_LAST[CNT_W-1:0] + 1'b1;"),
 ("GREEN lasts 9 cycles",             "S_GREEN:  last_count = GREEN_LAST[CNT_W-1:0];", "S_GREEN:  last_count = GREEN_LAST[CNT_W-1:0] - 1'b1;"),
 ("GREEN skips YELLOW",               "S_GREEN:  next_state = done ? S_YELLOW : S_GREEN;", "S_GREEN:  next_state = done ? S_RED : S_GREEN;"),
 ("illegal state locks up",           "default:  next_state = S_RED;          // illegal state -> recover", "default:  next_state = state;"),
 ("illegal 000 not recovered",        "default:  next_state = S_RED;          // illegal state -> recover", "3'b000:   next_state = 3'b000;\n            default:  next_state = S_RED;"),
 ("reset is synchronous",             "always @(posedge clk or posedge rst) begin\n        if (rst) state <= S_RED;", "always @(posedge clk) begin\n        if (rst) state <= S_RED;"),
 ("reset ignored on terminal count",  "if (rst) state <= S_RED;\n        else     state <= next_state;", "if (rst && done !== 1'b1) state <= S_RED;\n        else     state <= next_state;"),
 ("counter not cleared on transition","else if (state != next_state)   counter <= {CNT_W{1'b0}};", "else if (1'b0)   counter <= {CNT_W{1'b0}};"),
 ("counter kept through GREEN",       "else if (state != next_state)   counter <= {CNT_W{1'b0}};", "else if (state != next_state && state != S_GREEN)   counter <= {CNT_W{1'b0}};"),
 ("reset leaves counter at 5",        "if (rst)                        counter <= {CNT_W{1'b0}};", "if (rst)                        counter <= 5;"),
 ("counter too narrow",               "localparam CNT_W = (clog2(MAX_CYCLES) > 0) ? clog2(MAX_CYCLES) : 1;", "localparam CNT_W = 3;"),
 ("green/yellow outputs swapped",     "assign green  = state[1];", "assign green  = state[2];"),
]

def run(rtl_text):
    with tempfile.TemporaryDirectory() as d:
        f = os.path.join(d, "dut.v"); open(f, "w").write(rtl_text)
        out = os.path.join(d, "sim")
        subprocess.run(["iverilog", "-g2012", "-o", out, f, TB], check=True, capture_output=True)
        r = subprocess.run(["vvp", out], capture_output=True, text=True, timeout=120)
        return "RESULT: PASS" in r.stdout

assert run(src), "baseline RTL must PASS before mutation testing means anything"
print("baseline: PASS")
missed = 0
for name, a, b in MUTANTS:
    assert a in src, f"mutation pattern not found: {name}"
    caught = not run(src.replace(a, b, 1))
    missed += (not caught)
    print(f"{'CAUGHT' if caught else 'MISSED'}  {name}")
print(f"\n{len(MUTANTS) - missed}/{len(MUTANTS)} mutants caught")
sys.exit(1 if missed else 0)
