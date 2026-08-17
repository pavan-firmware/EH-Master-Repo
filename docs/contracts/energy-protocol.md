# Fixed-Point Energy Protocol Specification

The embedded energy telemetry protocol strictly uses **deterministic fixed-point integers**. No floating-point values (IEEE 754 floats/doubles) are allowed in embedded wire contracts.

## Wire Fields & Scaling
* `v_mv` (uint32): Voltage in millivolts ($1\text{ V} = 1000\text{ mV}$)
* `i_ma` (uint32): Current in milliamperes ($1\text{ A} = 1000\text{ mA}$)
* `p_mw` (uint32): Active power in milliwatts ($1\text{ W} = 1000\text{ mW}$)
* `e_tot_wh` (uint64): Cumulative energy in Watt-hours ($1\text{ Wh} = 1\text{ Wh}$)
* `e_int_mwh` (uint32): Interval delta energy in milliwatt-hours ($1\text{ Wh} = 1000\text{ mWh}$)
* `freq_mhz` (uint32): Line frequency in millihertz ($50\text{ Hz} = 50000\text{ mHz}$)
* `pf_x1000` (uint16): Power factor scaled by 1000 ($0\text{ to }1000$)
* `flags` (uint8): Bitfield (`Bit 0`: Counter Reset, `Bit 1`: Sensor Fault)

## Rollover & Overflow
`e_tot_wh` as `uint64` supports monotonic accumulation up to $1.84\times 10^{19}\text{ Wh}$ ($1.84\times 10^{13}\text{ MWh}$), eliminating overflow concerns.
