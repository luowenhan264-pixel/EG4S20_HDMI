# Invoked by build.ps1. Each stage runs in a fresh TD process and directory.
if {![info exists ::env(PLAYER_RUN_DIR)] || ![info exists ::env(PLAYER_STAGE)] || ![info exists ::env(TD_HOME)]} {
    puts stderr "Run build.ps1; PLAYER_RUN_DIR, PLAYER_STAGE and TD_HOME are required."
    exit 1
}
cd [file join $::env(PLAYER_RUN_DIR) $::env(PLAYER_STAGE)]
if {[catch {source [file join $::env(TD_HOME) doc scripts DefaultFlow.tcl]} err]} {
    puts stderr "BUILD FAILED: $err"
    puts stderr $::errorInfo
    exit 1
}
set f [open SUCCESS w]
puts $f "Completed [clock format [clock seconds]]"
close $f
exit 0

