SRC     = traffic_light.v
BUILD   = build

.PHONY: sim verify clean

sim: $(BUILD)/tlc_basic.vvp
	vvp $<

verify: $(BUILD)/tlc_verif.vvp
	vvp $<

$(BUILD)/tlc_basic.vvp: $(SRC) traffic_light_tb.v | $(BUILD)
	iverilog -o $@ $^

$(BUILD)/tlc_verif.vvp: $(SRC) traffic_light_verif_tb.sv | $(BUILD)
	iverilog -g2012 -gassertions -o $@ $^

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
