# topic1_hdmi_player — TD 6.2.1 CLI build
# Usage:
#   D:/TD_6.2.1/bin/td_commands_prompt.exe C:/Users/AUSU/Desktop/FPGA/work/topic1_hdmi_player/build_topic1.tcl

set root     "C:/Users/AUSU/Desktop/FPGA/work/topic1_hdmi_player"
set prj_dir  "$root/src/td_project"
set syn_dir  "$prj_dir/topic1_hdmi_player_Runs/syn_1"
set phy_dir  "$prj_dir/topic1_hdmi_player_Runs/phy_1"
set flow_tcl "D:/TD_6.2.1/doc/scripts/DefaultFlow.tcl"
set out_bit  "C:/Users/AUSU/Desktop/FPGA/work/output_bit/topic1_hdmi_player.bit"
set out_dir  "C:/Users/AUSU/Desktop/FPGA/work/output_bit"

puts "==== topic1_hdmi_player build ===="

# ========== SYN ==========
puts "==== SYN: $syn_dir ===="
cd $syn_dir
puts "cwd=[pwd]"
puts "settings exists=[file exists settings.cfg]"

# 显式在全局命名空间设置 flow 变量（避免 proc 局部作用域问题）
set ADCList {"../../../user_source/constraints_source/pin.adc"}
set IpSDCList { rfifo_32_32_512 ../../../user_source/hdl_source/ip/afifo_32_16_256.tcl wfifo_32_32_512 ../../../user_source/hdl_source/ip/afifo_16_32_256.tcl }
set SDCList {"../../../user_source/constraints_source/timing.sdc"}
set area_option -packarea
set device_name eagle_s20.db
set end_step opt_gate
set package_name EG4S20BG256
set prj_name {topic1_hdmi_player}
set run_type syn
set start_step read_design
set top_model_name {top}

# DefaultFlow 在无 alRun 时会再次 source ./settings.cfg
if {[info exists alRun]} { unset alRun }

puts "SYN start $start_step -> $end_step"
if {[catch {source $flow_tcl} err]} {
  puts "SYN ERROR: $err"
} else {
  puts "==== SYN done ===="
}

# ========== PHY ==========
puts "==== PHY: $phy_dir ===="
# phy_1 需要与 syn 同名的 .prj（GUI 会自动生成；CLI 需复制）
file copy -force "$syn_dir/$prj_name.prj" "$phy_dir/$prj_name.prj"
cd $phy_dir
puts "cwd=[pwd]"

set ADCList {"../../../user_source/constraints_source/pin.adc"}
set IpSDCList { rfifo_32_32_512 ../../../user_source/hdl_source/ip/afifo_32_16_256.tcl wfifo_32_32_512 ../../../user_source/hdl_source/ip/afifo_16_32_256.tcl }
set SDCList {"../../../user_source/constraints_source/timing.sdc"}
set area_option -packarea
set arr_filter false
set device_name eagle_s20.db
set drHoldFix on
set end_step bitgen
set package_name EG4S20BG256
set parent ../syn_1
set prj_name {topic1_hdmi_player}
set run_type phy
set start_step opt_place
set top_model_name {top}

if {[info exists alRun]} { unset alRun }

puts "PHY start $start_step -> $end_step"
if {[catch {source $flow_tcl} err]} {
  puts "PHY ERROR: $err"
} else {
  puts "==== PHY done ===="
}

set candidates [concat \
  [glob -nocomplain "$phy_dir/*.bit"] \
  [glob -nocomplain "$phy_dir/*/*.bit"]]

if {[llength $candidates] == 0} {
  puts "ERROR: no .bit produced under phy_1 — use GUI Process->Run if needed"
} else {
  set src_bit [lindex $candidates 0]
  puts "Found bit: $src_bit"
  file mkdir $out_dir
  file copy -force $src_bit $out_bit
  puts "Copied to: $out_bit"
  puts "==== build done ===="
}
