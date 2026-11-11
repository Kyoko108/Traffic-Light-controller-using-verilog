// traffic_light_verif_tb.sv
// Self-checking testbench for traffic_light.v (Icarus Verilog 12, -g2012).
//
// Checking is black-box: every comparison uses only the red/yellow/green pins
// and a reference model that tracks position within the 23-cycle sequence.
// The single hierarchical reference, dut.state, is used only for fault
// injection (forcing illegal states), because there is no other way in.
//
// Run:  iverilog -g2012 -o tlc_tb.vvp traffic_light.v traffic_light_verif_tb.sv
//       vvp tlc_tb.vvp [+SEED=<n>]
`timescale 1ns/1ps

module traffic_light_verif_tb;

  localparam int RED_N    = 10;
  localparam int GREEN_N  = 10;
  localparam int YELLOW_N = 3;
  localparam int PERIOD   = RED_N + GREEN_N + YELLOW_N;   // 23

  // ------------------------------------------------------------------
  // DUT and clock
  // ------------------------------------------------------------------
  logic clk = 0;
  logic rst = 1;
  wire  red, yellow, green;

  traffic_light #(.RED_CYCLES(RED_N), .GREEN_CYCLES(GREEN_N),
                  .YELLOW_CYCLES(YELLOW_N)) dut (
    .clk(clk), .rst(rst), .red(red), .yellow(yellow), .green(green));

  always #5 clk = ~clk;                 // posedge at 5, 15, ... ; negedge at 10, 20, ...

  // ------------------------------------------------------------------
  // Reference model: position 0..22 within the sequence, reset by rst.
  // Independent formulation (modulo counter), not a copy of the FSM.
  // ------------------------------------------------------------------
  int   pos = 0;
  int   pos_d = 0;                      // pos delayed 1 ns, for coverage sampling
  logic model_sync = 0;                 // resync pulse used after fault injection

  always @(posedge clk or posedge rst) begin
    if (rst || model_sync)      pos <= 0;
    else if (pos == PERIOD-1)   pos <= 0;
    else                        pos <= pos + 1;
  end
  always @(pos) pos_d <= #1 pos;

  wire exp_red    = (pos <  RED_N);
  wire exp_green  = (pos >= RED_N) && (pos < RED_N + GREEN_N);
  wire exp_yellow = (pos >= RED_N + GREEN_N);

  // ------------------------------------------------------------------
  // Scoreboard: sampled on negedge, away from every posedge/reset event
  // ------------------------------------------------------------------
  int   errors   = 0;
  logic check_en = 0;

  task automatic report_error(string msg);
    errors++;
    $display("[%0t] ERROR: %s", $time, msg);
  endtask

  always @(negedge clk) if (check_en) begin
    if ((^{red, yellow, green}) === 1'bx) begin
      report_error("X/Z on a light output");
    end else begin
      if ((int'(red) + int'(yellow) + int'(green)) != 1)
        report_error($sformatf("not exactly one light on (R%b Y%b G%b)", red, yellow, green));
      if ({red, green, yellow} !== {exp_red, exp_green, exp_yellow})
        report_error($sformatf("pins R%b G%b Y%b, model expects R%b G%b Y%b at position %0d",
                               red, green, yellow, exp_red, exp_green, exp_yellow, pos));
    end
  end

  // ------------------------------------------------------------------
  // Coverage (bins are measured from the model, not from stimulus intent)
  // ------------------------------------------------------------------
  int cov_rst_pos [0:PERIOD-1];         // reset arrived while the sequence was at this position
  int cov_ill_ok  [0:4];                // recovery from each injected illegal code
  int cov_async_nonred = 0;             // async reset applied from GREEN/YELLOW, RED seen immediately
  int cov_wraps        = 0;             // full uninterrupted sequence wraps observed

  always @(posedge rst) if (check_en) cov_rst_pos[pos_d] = cov_rst_pos[pos_d] + 1;
  always @(negedge clk) if (check_en && !rst && pos == PERIOD-1) cov_wraps = cov_wraps + 1;

  // ------------------------------------------------------------------
  // Seedable randomness
  // ------------------------------------------------------------------
  integer seed;
  function integer rnd(input integer lo, input integer hi);
    rnd = lo + ({$random(seed)} % (hi - lo + 1));
  endfunction

  // ------------------------------------------------------------------
  // Stimulus tasks
  // ------------------------------------------------------------------
  logic [2:0] ill_codes [0:4];

  // Precondition: just after an async deassert (negedge+2), model pos == 0.
  // Waits p clock edges, asserts rst asynchronously (mid-cycle), checks RED
  // immediately with no clock edge in between, holds across a negedge, then
  // deasserts mid-cycle. Postcondition == precondition.
  task automatic async_reset_at(input int p);
    begin
      if (p == 0) #1 rst = 1;
      else begin repeat (p) @(posedge clk); #2 rst = 1; end
      #1;
      if (!(red === 1 && green === 0 && yellow === 0))
        report_error($sformatf("async reset at position %0d did not force RED immediately", p));
      else if (p >= RED_N)
        cov_async_nonred = cov_async_nonred + 1;
      @(negedge clk);
      #2 rst = 0;
    end
  endtask

  task automatic inject_illegal(input int idx);
    begin
      @(negedge clk);
      #1;
      case (idx)
        0: force dut.state = 3'b000;
        1: force dut.state = 3'b011;
        2: force dut.state = 3'b101;
        3: force dut.state = 3'b110;
        default: force dut.state = 3'b111;
      endcase
      check_en = 0;                     // pins are meaningless while forced
      #1 release dut.state;
      model_sync = 1;                   // DUT recovers to RED at the next edge
      @(posedge clk);
      #1 model_sync = 0;
      if (!(red === 1 && green === 0 && yellow === 0))
        report_error($sformatf("no recovery to RED from illegal state %b", ill_codes[idx]));
      else
        cov_ill_ok[idx] = cov_ill_ok[idx] + 1;
      check_en = 1;
    end
  endtask

  task automatic random_event;
    int kind, n;
    begin
      repeat (rnd(1, 30)) @(posedge clk);
      kind = rnd(0, 3);
      case (kind)
        0: begin                         // clock-edge-timed reset, 1..4 cycles
             rst <= 1;
             repeat (rnd(1, 4)) @(posedge clk);
             rst <= 0;
           end
        1, 2: begin                      // async pulse: runt (1 ns) or 1..3 cycles
             n = rnd(0, 3);
             #2 rst = 1;
             if (n == 0) #1;
             else begin repeat (n) @(posedge clk); #3; end
             rst = 0;
           end
        3: inject_illegal(rnd(0, 4));
      endcase
    end
  endtask

  // ------------------------------------------------------------------
  // Main sequence
  // ------------------------------------------------------------------
  int p, i, holes;

  initial begin
    if (!$value$plusargs("SEED=%d", seed)) seed = 1;
    $display("SEED=%0d  (reproduce with +SEED=%0d)", seed, seed);
    for (i = 0; i < PERIOD; i++) cov_rst_pos[i] = 0;
    for (i = 0; i < 5; i++)      cov_ill_ok[i]  = 0;
    ill_codes[0] = 3'b000; ill_codes[1] = 3'b011; ill_codes[2] = 3'b101;
    ill_codes[3] = 3'b110; ill_codes[4] = 3'b111;

    // initial reset, released asynchronously mid-cycle
    repeat (3) @(posedge clk);
    @(negedge clk); #2 rst = 0;
    check_en = 1;

    // 1. free-running: several complete sequences
    repeat (PERIOD * 3) @(posedge clk);

    // 2. async reset at every position 0..22, RED checked with no clock edge
    for (p = 0; p < PERIOD; p++) async_reset_at(p);

    // 3. clock-edge-timed reset (rst changes on the edge) at positions 1..22
    for (p = 1; p < PERIOD; p++) begin
      repeat (p) @(posedge clk);
      rst <= 1;
      @(posedge clk);
      rst <= 0;
    end

    // 4. illegal-state injection, landing in different phases
    for (i = 0; i < 5; i++) begin
      repeat (3 + 5*i) @(posedge clk);
      inject_illegal(i);
    end

    // 5. seeded random events
    for (i = 0; i < 60; i++) random_event();
    repeat (PERIOD * 2) @(posedge clk);

    // ----- report -----
    holes = 0;
    $display("\n=== Coverage ===");
    for (i = 0; i < PERIOD; i++) if (cov_rst_pos[i] == 0) holes++;
    $display("Reset-arrival positions hit : %0d / %0d", PERIOD - holes, PERIOD);
    if (holes != 0) report_error("coverage hole: reset never arrived at some sequence positions");
    holes = 0;
    for (i = 0; i < 5; i++) if (cov_ill_ok[i] == 0) begin
      holes++;
      report_error($sformatf("coverage hole: illegal code %b never injected", ill_codes[i]));
    end
    $display("Illegal codes recovered     : %0d / 5", 5 - holes);
    if (cov_async_nonred == 0) report_error("coverage hole: no async reset from GREEN/YELLOW");
    $display("Async resets from non-RED   : %0d", cov_async_nonred);
    if (cov_wraps == 0) report_error("coverage hole: no uninterrupted full sequence");
    $display("Sequence wraps observed     : %0d", cov_wraps);

    $display("\nTotal errors: %0d", errors);
    if (errors == 0) $display("RESULT: PASS");
    else             $display("RESULT: FAIL");
    $finish;
  end

  initial begin
    #1000000;
    $display("TIMEOUT");
    $display("RESULT: FAIL");
    $finish;
  end

endmodule
