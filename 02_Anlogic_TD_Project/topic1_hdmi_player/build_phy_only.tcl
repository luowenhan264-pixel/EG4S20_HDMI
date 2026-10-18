# Continue PHY+bitgen after successful SYN
set phy_dir  "C:/Users/AUSU/Desktop/FPGA/work/topic1_hdmi_player/src/td_project/topic1_hdmi_player_Runs/phy_1"
set flow_tcl "D:/TD_6.2.1/doc/scripts/DefaultFlow.tcl"
set out_bit  "C:/Users/AUSU/Desktop/FPGA/work/output_bit/topic1_hdmi_player.bit"
set out_dir  "C:/Users/AUSU/Desktop/FPGA/work/output_bit"

cd $phy_dir
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

puts "PHY start $start_step -> $end_step cwd=[pwd]"
source $flow_tcl
puts "==== PHY done ===="

set candidates [glob -nocomplain "$phy_dir/*.bit"]
if {[llength $candidates] == 0} {
  puts "ERROR: no bit"
} else {
  set src_bit [lindex $candidates 0]
  file mkdir $out_dir
  file copy -force $src_bit $out_bit
  puts "Copied $src_bit -> $out_bit"
}
