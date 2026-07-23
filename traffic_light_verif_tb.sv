// =============================================================================
// traffic_light_verif_tb.sv
//
// Self-checking verification environment for traffic_light.v
//
// SCOPE / HONESTY NOTES (read before you present this anywhere):
//
// 1. This is NOT full UVM. For a 3-state, 2-output FSM, class-based UVM
//    (driver/monitor/sequencer/scoreboard hierarchy) is architectural
//    overkill and reads as copy-pasted boilerplate to anyone who actually
//    works in verification. What's implemented instead, and is genuinely
//    uncommon at undergrad level:
//      - Self-checking procedural assertions (safety + liveness + ordering)
//      - Randomized reset injection (directed-random hybrid stimulus)
//      - Functional coverage tracking with a printed coverage report
//
// 2. TOOL LIMITATION (verified directly, not assumed): Icarus Verilog 12.0
//    does NOT support IEEE-1800 concurrent assertions -- i.e. standalone
//    `property ... endproperty` blocks with a clocking event and
//    `assert property (...)`. Compiling one throws a syntax error on this
//    toolchain. Below, every check is written as a PROCEDURAL immediate
//    assertion (`assert (expr) else ...` inside an always block), which
//    IS supported and simulates correctly -- confirmed by running it.
//    Each checker also has the equivalent formal SVA property written as a
//    comment directly above it, labeled REFERENCE (SVA), so you can show
//    you know proper concurrent-assertion syntax even though this
//    toolchain can't execute it. If you get access to Questa/VCS/Xcelium/
//    Verilator, those reference properties are what you'd actually compile.
//
// 3. Coverage is manual counters/bins, not `covergroup`/`coverpoint`
//    (also unsupported on Icarus). Functionally equivalent for this scope,
//    explicitly labeled as a substitute.
//
// Run:
//   iverilog -g2012 -gassertions -o tlc_tb.vvp traffic_light.v traffic_light_verif_tb.sv
//   vvp tlc_tb.vvp
// =============================================================================

`timescale 1ns/1ps

module traffic_light_verif_tb;

    // ---------------------------------------------------------------
    // DUT hookup
    // ---------------------------------------------------------------
    logic clk;
    logic rst;
    logic red, yellow, green;

    traffic_light dut (
        .clk(clk),
        .rst(rst),
        .red(red),
        .yellow(yellow),
        .green(green)
    );

    localparam [1:0] RED_S = 2'b00, GREEN_S = 2'b01, YELLOW_S = 2'b10;

    // ---------------------------------------------------------------
    // Clock generation
    // ---------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz

    // ---------------------------------------------------------------
    // Scoreboard state
    // ---------------------------------------------------------------
    int error_count = 0;

    task automatic report_error(string msg);
        error_count++;
        $display("[%0t] ERROR: %s", $time, msg);
    endtask

    // ---------------------------------------------------------------
    // CHECKER 1: Mutual exclusion (safety property)
    //
    // REFERENCE (SVA, for a tool that supports concurrent assertions):
    //   property p_mutual_exclusion;
    //     @(posedge clk) disable iff (rst) $onehot0({red, yellow, green});
    //   endproperty
    //   assert property (p_mutual_exclusion);
    // ---------------------------------------------------------------
    // NOTE: originally written using $countones({red,yellow,green}) <= 1.
    // Verified by direct isolated test that this Icarus Verilog 12.0 build
    // returns garbage from $countones/$onehot0 on packed concatenations --
    // a real tool bug, confirmed before shipping this file, not assumed.
    // Replaced with a manual, portable bit count. Also note: naive
    // `red + yellow + green` truncates to 1-bit width in Verilog's
    // self-determined expression sizing (1+1=0, not 2) -- casting each
    // operand to int avoids that silently-wrong result.
    always @(negedge clk) begin
        if (!rst) begin
            assert ((int'(red) + int'(yellow) + int'(green)) <= 1)
                else report_error("Mutual exclusion violated -- more than one light on simultaneously");
        end
    end

    // ---------------------------------------------------------------
    // CHECKER 2: Reset forces RED
    //
    // REFERENCE (SVA):
    //   property p_reset_forces_red;
    //     @(posedge clk) rst |-> red;
    //   endproperty
    //   assert property (p_reset_forces_red);
    // ---------------------------------------------------------------
    always @(negedge clk) begin
        if (rst) begin
            assert (red && !green && !yellow)
                else report_error("Reset asserted but red is not the sole active output");
        end
    end

    // ---------------------------------------------------------------
    // CHECKER 3: Output-to-state consistency
    // Confirms the combinational output logic actually matches the FSM
    // state on every cycle, not just "some light is on".
    // ---------------------------------------------------------------
    always @(negedge clk) begin
        if (!rst) begin
            case (dut.current_state)
                RED_S:    assert (red && !green && !yellow)
                              else report_error("current_state=RED but outputs don't reflect it");
                GREEN_S:  assert (green && !red && !yellow)
                              else report_error("current_state=GREEN but outputs don't reflect it");
                YELLOW_S: assert (yellow && !red && !green)
                              else report_error("current_state=YELLOW but outputs don't reflect it");
                default:  report_error("current_state holds an illegal/unreachable value");
            endcase
        end
    end

    // ---------------------------------------------------------------
    // CHECKER 4: State duration + ordering (liveness + no illegal transitions)
    //
    // REFERENCE (SVA), one of three analogous properties:
    //   property p_red_duration;
    //     @(posedge clk) disable iff (rst)
    //       $rose(red) |-> red[*10] ##1 green;
    //   endproperty
    //   assert property (p_red_duration);
    //   (GREEN and YELLOW versions follow the same pattern with 10 and 3
    //    cycle counts respectively, and ##1 yellow / ##1 red as the target.)
    //
    // Implemented procedurally below by tracking how long the FSM stays
    // in each state and what state it transitions to.
    // ---------------------------------------------------------------
    reg [1:0] prev_state;
    int run_length;
    bit first_cycle_after_reset;

    always @(negedge clk) begin
        if (rst) begin
            prev_state <= dut.current_state;
            run_length <= 1;
            first_cycle_after_reset <= 1;
        end else begin
            if (first_cycle_after_reset) begin
                // just came out of reset -- start tracking cleanly, no
                // transition check on this cycle since there's no valid
                // prior run to compare against.
                first_cycle_after_reset <= 0;
                prev_state <= dut.current_state;
                run_length <= 1;
            end else if (dut.current_state != prev_state) begin
                // A transition just happened -- check the run that just
                // ended matched spec, and that it went to the correct
                // next state.
                case (prev_state)
                    RED_S: begin
                        assert (run_length == 10)
                            else report_error($sformatf("RED held %0d cycles, expected 10", run_length));
                        assert (dut.current_state == GREEN_S)
                            else report_error("Illegal transition: RED did not go to GREEN");
                    end
                    GREEN_S: begin
                        assert (run_length == 10)
                            else report_error($sformatf("GREEN held %0d cycles, expected 10", run_length));
                        assert (dut.current_state == YELLOW_S)
                            else report_error("Illegal transition: GREEN did not go to YELLOW");
                    end
                    YELLOW_S: begin
                        assert (run_length == 3)
                            else report_error($sformatf("YELLOW held %0d cycles, expected 3", run_length));
                        assert (dut.current_state == RED_S)
                            else report_error("Illegal transition: YELLOW did not go to RED");
                    end
                endcase
                prev_state <= dut.current_state;
                run_length <= 1;
            end else begin
                run_length <= run_length + 1;
            end
        end
    end

    // ---------------------------------------------------------------
    // FUNCTIONAL COVERAGE (manual bins -- see header note on Icarus)
    // ---------------------------------------------------------------
    int cov_state_red    = 0;
    int cov_state_green  = 0;
    int cov_state_yellow = 0;
    int cov_reset_during_red    = 0;
    int cov_reset_during_green  = 0;
    int cov_reset_during_yellow = 0;
    int cov_full_cycle_completed = 0;

    int cycle_stage = 0; // 0=waiting for red, 1=saw red, 2=saw green, 3=saw yellow

    always @(negedge clk) begin
        if (rst) begin
            // Use prev_state (from CHECKER 4, tracked via nonblocking
            // assignment) rather than dut.current_state: by this negedge,
            // current_state has already been forced to RED by the reset
            // itself, so sampling it here would always read RED and never
            // register a reset during GREEN or YELLOW. prev_state still
            // holds the state as it was the cycle before reset hit,
            // because it's only updated via nonblocking assignment (same
            // race-safety reasoning as everywhere else in this file).
            case (prev_state)
                RED_S:    cov_reset_during_red++;
                GREEN_S:  cov_reset_during_green++;
                YELLOW_S: cov_reset_during_yellow++;
            endcase
        end else begin
            case (dut.current_state)
                RED_S:    cov_state_red++;
                GREEN_S:  cov_state_green++;
                YELLOW_S: cov_state_yellow++;
            endcase

            case (cycle_stage)
                0: if (dut.current_state == RED_S)    cycle_stage = 1;
                1: if (dut.current_state == GREEN_S)  cycle_stage = 2;
                2: if (dut.current_state == YELLOW_S) cycle_stage = 3;
                3: if (dut.current_state == RED_S) begin
                       cov_full_cycle_completed++;
                       cycle_stage = 1;
                   end
            endcase
        end
    end

    // ---------------------------------------------------------------
    // STIMULUS
    // ---------------------------------------------------------------
    // rst is driven with NONBLOCKING assignment throughout this stimulus
    // block. A blocking assignment here would race the DUT's own
    // @(posedge clk or posedge rst) block on the exact edge rst changes --
    // simulator scheduling order between the two processes is unspecified,
    // so the DUT could sample either the old or new value of rst on that
    // edge. Nonblocking assignment guarantees the DUT always sees the OLD
    // value on the edge you change it, and the new value from the next
    // edge onward -- deterministic, tool-independent behavior. This was
    // caught by exactly this kind of off-by-one showing up in the RED
    // duration check.
    initial begin
        $display("=== Traffic Light Controller Verification ===");
        rst <= 1;
        repeat (3) @(posedge clk);
        rst <= 0;

        // Run long enough to cover several full RED->GREEN->YELLOW cycles
        // (each cycle is 23 clocks: 10+10+3).
        repeat (23 * 15) @(posedge clk);

        // --- Directed reset-injection corner cases ---
        // Coverage on an earlier run showed pure randomization can miss a
        // state entirely by chance (reset landed in RED every time, never
        // GREEN or YELLOW, across 8 random draws) -- exactly the kind of
        // gap coverage tracking exists to catch. Don't leave hitting every
        // state to luck: force it once each, directed, before layering
        // randomization on top.
        //   cycle offset 4  -> lands inside RED  (RED spans offsets 0-9)
        //   cycle offset 14 -> lands inside GREEN (GREEN spans 10-19)
        //   cycle offset 21 -> lands inside YELLOW (YELLOW spans 20-22)
        repeat (4)  @(posedge clk); rst <= 1; @(posedge clk); rst <= 0; repeat (23) @(posedge clk);
        repeat (14) @(posedge clk); rst <= 1; @(posedge clk); rst <= 0; repeat (23) @(posedge clk);
        repeat (21) @(posedge clk); rst <= 1; @(posedge clk); rst <= 0; repeat (23) @(posedge clk);

        // --- Randomized reset injection mid-sequence ---
        // Now layer randomized resets on top of the guaranteed directed
        // hits, to probe boundary/off-by-one points the directed cases
        // don't specifically target.
        for (int i = 0; i < 8; i++) begin
            int wait_cycles;
            wait_cycles = $urandom_range(1, 25); // spans across all 3 states
            repeat (wait_cycles) @(posedge clk);
            rst <= 1;
            @(posedge clk);
            rst <= 0;
            repeat (23) @(posedge clk); // let a full cycle complete before next reset
        end

        repeat (46) @(posedge clk);

        // ---------------------------------------------------------------
        // FINAL REPORT
        // ---------------------------------------------------------------
        $display("\n=== Coverage Report (manual bins) ===");
        $display("RED state cycles observed    : %0d", cov_state_red);
        $display("GREEN state cycles observed  : %0d", cov_state_green);
        $display("YELLOW state cycles observed : %0d", cov_state_yellow);
        $display("Reset asserted during RED    : %0d", cov_reset_during_red);
        $display("Reset asserted during GREEN  : %0d", cov_reset_during_green);
        $display("Reset asserted during YELLOW : %0d", cov_reset_during_yellow);
        $display("Full RED->GREEN->YELLOW->RED cycles completed: %0d", cov_full_cycle_completed);

        if (cov_state_red == 0 || cov_state_green == 0 || cov_state_yellow == 0)
            report_error("Coverage hole: not all three states were exercised");
        if (cov_reset_during_red == 0 || cov_reset_during_green == 0 || cov_reset_during_yellow == 0)
            report_error("Coverage hole: reset was not tested from all three states");
        if (cov_full_cycle_completed == 0)
            report_error("Coverage hole: never observed a full clean cycle");

        $display("\n=== Assertion Summary ===");
        $display("Total errors: %0d", error_count);
        if (error_count == 0)
            $display("RESULT: PASS -- all safety/liveness/ordering checks held, all coverage bins hit");
        else
            $display("RESULT: FAIL -- see ERROR lines above");

        $finish;
    end

    // Safety timeout in case something hangs
    initial begin
        #100000;
        $display("TIMEOUT -- simulation did not finish in expected time");
        $finish;
    end

endmodule
