# pynq_z2.xdc
# The Rule 30 PRNG IP itself is AXI-only (PS<->PL over the interconnect) and
# needs NO external pin constraints to function. Uncomment below only if you
# add a debug output (e.g. lower 4 PRNG bits driving the onboard LEDs) for a
# visual demo -- otherwise leave this file empty; Vivado is fine with that.

## Onboard LEDs (uncomment + wire in your block design / wrapper if used)
# set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
# set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
# set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
# set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];
