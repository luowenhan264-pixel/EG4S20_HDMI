


`define   DATA_WIDTH                        32
`define   ADDR_WIDTH                        21
`define   DM_WIDTH                          4

`define   ROW_WIDTH                        11
`define   BA_WIDTH                        2

// Must match sys_pll C1/C2. Parentheses are required when expanded in divisions.
`define   SDR_CLK_HZ                        50000000
`define   SDR_CLK_PERIOD                    (1000000000 / `SDR_CLK_HZ)
// Conservative 4096 refreshes/64 ms (15.62 us at 50 MHz), including for
// devices with 2048 physical row addresses. Do not lengthen when downclocking.
`define   SELF_REFRESH_INTERVAL             (64000000 / `SDR_CLK_PERIOD / 4096)

