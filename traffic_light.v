// Moore FSM traffic light controller.
// One-hot state; each light is driven directly by a state flop, so there is
// no output decode logic to glitch. Any illegal state recovers to RED.
module traffic_light #(
    parameter RED_CYCLES    = 10,
    parameter GREEN_CYCLES  = 10,
    parameter YELLOW_CYCLES = 3
) (
    input  wire clk,
    input  wire rst,      // async assert, active high
    output wire red,
    output wire yellow,
    output wire green
);

    function integer clog2(input integer v);
        integer i;
        begin
            clog2 = 0;
            for (i = v - 1; i > 0; i = i >> 1) clog2 = clog2 + 1;
        end
    endfunction

    localparam MAX_CYCLES = (RED_CYCLES > GREEN_CYCLES)
                          ? ((RED_CYCLES > YELLOW_CYCLES) ? RED_CYCLES : YELLOW_CYCLES)
                          : ((GREEN_CYCLES > YELLOW_CYCLES) ? GREEN_CYCLES : YELLOW_CYCLES);
    localparam CNT_W = (clog2(MAX_CYCLES) > 0) ? clog2(MAX_CYCLES) : 1;

    // Terminal count (duration - 1) per state, kept full width and sliced
    // to the counter width where used (avoids narrowing-assignment warnings)
    localparam [31:0] RED_LAST    = RED_CYCLES    - 1;
    localparam [31:0] GREEN_LAST  = GREEN_CYCLES  - 1;
    localparam [31:0] YELLOW_LAST = YELLOW_CYCLES - 1;

    // One-hot encoding: {YELLOW, GREEN, RED}
    localparam [2:0] S_RED    = 3'b001,
                     S_GREEN  = 3'b010,
                     S_YELLOW = 3'b100;

    reg [2:0]       state, next_state;
    reg [CNT_W-1:0] counter;
    reg [CNT_W-1:0] last_count;   // terminal count for the current state
    wire            done = (counter == last_count);

    // terminal count per state
    always @(*) begin
        case (state)
            S_GREEN:  last_count = GREEN_LAST[CNT_W-1:0];
            S_YELLOW: last_count = YELLOW_LAST[CNT_W-1:0];
            default:  last_count = RED_LAST[CNT_W-1:0];
        endcase
    end

    // next-state logic
    always @(*) begin
        case (state)
            S_RED:    next_state = done ? S_GREEN  : S_RED;
            S_GREEN:  next_state = done ? S_YELLOW : S_GREEN;
            S_YELLOW: next_state = done ? S_RED    : S_YELLOW;
            default:  next_state = S_RED;          // illegal state -> recover
        endcase
    end

    // state register
    always @(posedge clk or posedge rst) begin
        if (rst) state <= S_RED;
        else     state <= next_state;
    end

    // cycle counter (restarts on every state change)
    always @(posedge clk or posedge rst) begin
        if (rst)                        counter <= {CNT_W{1'b0}};
        else if (state != next_state)   counter <= {CNT_W{1'b0}};
        else                            counter <= counter + 1'b1;
    end

    // outputs: straight from state flops
    assign red    = state[0];
    assign green  = state[1];
    assign yellow = state[2];

endmodule
