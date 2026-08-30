# AXI Address Map — rule30_axi_v1_0

| Offset | Name       | Direction (SW view) | Description                                      |
|--------|------------|----------------------|---------------------------------------------------|
| 0x00   | SEED_REG   | Write                | Writing a 32-bit value pulses `load_seed` for one clock and loads it into the CA register. |
| 0x04   | DATA_REG   | Read                 | Returns the CA's current 32-bit state.            |

**Base address**: assigned by Vivado's Connection Automation — check **Window > Address Editor**
after building the block design. Update `DEFAULT_BASE_ADDR` in
`software/driver/rule30_driver.py` if it differs from `0x43C00000`.

**Known pitfall — fixed points**: seeding with `0x00000000` or `0xFFFFFFFF` produces a CA state
that never changes (Rule 30 maps both all-0 and all-1 states to themselves). The driver raises a
`ValueError` if you try. Always seed with something else — a hardware entropy source (XADC noise,
`/dev/urandom` on first boot, a button-press timestamp) is a reasonable non-zero seed source for a
real deployment.
