# HX4S20: actual PLL clocks, including the 50 MHz / +8 ns SDRAM clock.
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
derive_clocks
rename_clock -name {sd_card_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {ext_mem_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[1]}]
rename_clock -name {sdram_shift_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[2]}]
rename_clock -name {video_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {hdmi_5x_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[1]}]
rename_clock -name {audio_mclk} -source [get_ports {clk}] -master_clock {clk} [get_pins {u_audio_pll/pll_inst.clkc[2]}]

# I2S uses oversampling synchronizers in I2S_receiver. Pixel and serializer
# clocks remain RELATED and timed; the SDRAM interface also remains timed.
set_clock_groups -asynchronous \
    -group [get_clocks {audio_mclk}] \
    -group [get_clocks {video_clk hdmi_5x_clk sd_card_clk ext_mem_clk sdram_shift_clk}]

# rst_all is ONLY the asynchronous request to the five player_reset_sync
# instances (15 RTL preset pins, with physical replicas after packing).
# No functional register consumes this raw net.
# Scope to the dedicated input net because TD packs FFs into unrelated-named
# logic cells and does not reliably retain per-pin exception names after packing.
# Synchronizer D/Q settling and downstream LOCAL reset recovery remain timed.
set_false_path -through [get_nets {rst_all}]

