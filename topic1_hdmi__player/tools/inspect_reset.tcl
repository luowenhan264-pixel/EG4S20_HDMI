# Set PLAYER_AUDIT_RUN to an existing completed build directory.
if {![info exists env(PLAYER_AUDIT_RUN)]} { error "Set PLAYER_AUDIT_RUN first" }
set run [file normalize $env(PLAYER_AUDIT_RUN)]
cd [file join $run phy]
import_device eagle_s20.db -package EG4S20BG256
open_project topic1_hdmi_player.prj -noanalyze
import_db topic1_hdmi_player_pr.db
puts "RESET_NET=[get_nets {rst_all}]"
puts "RESET_PINS=[get_pins -of [get_nets {rst_all}]]"
set root [file normalize [file join [file dirname [info script]] ..]]
set input [open [file join $root src user_source constraints_source timing.sdc] r]
set sdc [read $input]
close $input
set sdc [string map [list {set_false_path -through [get_nets {rst_all}]} {}] $sdc]
set audit [file join $run reset_exception_disabled.sdc]
set output [open $audit w]
puts $output $sdc
close $output
clear_sdc -user
read_sdc $audit
update_timing -mode final
report_timing_summary -file ../reset_exception_disabled.timing
puts "RESET_AUDIT_COMPLETE"
exit
