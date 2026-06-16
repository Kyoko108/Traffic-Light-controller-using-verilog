`timescale 1ns/1ps

module traffic_light_tb;

reg clk;
reg rst;

wire red;
wire yellow;
wire green;

traffic_light dut(
    .clk(clk),
    .rst(rst),
    .red(red),
    .yellow(yellow),
    .green(green)
);

initial
begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial
begin
    rst = 1;
    #20 rst = 0;

    #300;
    $finish;
end

initial
begin
    $monitor("t=%0t state: R=%b Y=%b G=%b",
              $time, red, yellow, green);
end

endmodule