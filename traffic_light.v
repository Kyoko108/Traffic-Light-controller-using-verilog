module traffic_light(
    input clk,
    input rst,
    output reg red,
    output reg yellow,
    output reg green
);

parameter RED    = 2'b00;
parameter GREEN  = 2'b01;
parameter YELLOW = 2'b10;

reg [1:0] current_state, next_state;
reg [3:0] counter;

// State register
always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        current_state <= RED;
        counter <= 0;
    end
    else
    begin
        current_state <= next_state;

        case(current_state)
            RED:
                if(counter == 9)
                    counter <= 0;
                else
                    counter <= counter + 1;

            GREEN:
                if(counter == 9)
                    counter <= 0;
                else
                    counter <= counter + 1;

            YELLOW:
                if(counter == 2)
                    counter <= 0;
                else
                    counter <= counter + 1;
        endcase
    end
end

// Next-state logic
always @(*)
begin
    next_state = current_state;

    case(current_state)

        RED:
            if(counter == 9)
                next_state = GREEN;

        GREEN:
            if(counter == 9)
                next_state = YELLOW;

        YELLOW:
            if(counter == 2)
                next_state = RED;

    endcase
end

// Output logic
always @(*)
begin
    red    = 0;
    yellow = 0;
    green  = 0;

    case(current_state)
        RED:    red = 1;
        GREEN:  green = 1;
        YELLOW: yellow = 1;
    endcase
end

endmodule