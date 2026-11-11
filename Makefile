SRC     = traffic_light.v
BUILD   = build
SEED   ?= 1

.PHONY: sim verify mutate clean

sim: $(BUILD)/tlc_basic.vvp
	vvp $<

# vvp exits 0 even when the testbench reports failure, so gate on the log.
verify: $(BUILD)/tlc_verif.vvp
	vvp $< +SEED=$(SEED) | tee $(BUILD)/verify.log
	@grep -q "RESULT: PASS" $(BUILD)/verify.log

mutate:
	python3 mutate.py

$(BUILD)/tlc_basic.vvp: $(SRC) traffic_light_tb.v | $(BUILD)
	iverilog -g2012 -o $@ $^

$(BUILD)/tlc_verif.vvp: $(SRC) traffic_light_verif_tb.sv | $(BUILD)
	iverilog -g2012 -o $@ $^

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
