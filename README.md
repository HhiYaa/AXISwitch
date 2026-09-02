# AXISwitch
# AXI-Stream Switch (axis_arbiter)

🚧 **Work in progress** — functional but still being developed and tested.

A parametric AXI4-Stream switch that routes beats from multiple RX ports to multiple TX ports based on `TDEST`, using a configurable lookup table (`TDEST_MAP`, defaults to round-robin).

**Files:** `Axi_Switch.sv` (module), `Axi_switch_tb.sv` (testbench)

**Simulate:**
```bash
iverilog -g2012 -o sim.out Axi_Switch.sv Axi_switch_tb.sv
vvp sim.out
```

**Known gaps:** no arbitration for simultaneous RX contention on the same TX port; edge cases (`NUM_TX=1`, larger `TDEST_WIDTH`) only spot-checked; testbench coverage still basic.
