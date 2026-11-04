param([string]$ModelSimBin = '', [string[]]$Tests = @('tb_bmp_read','tb_video','tb_player','tb_fade','tb_memory_schedule','tb_audio_link','tb_controls','tb_audio_modes','tb_settings_osd','tb_runtime_player','tb_cue_config_boundary','tb_extensions_flow','tb_picture_adjust','tb_display_overlay','tb_bmp_scale','tb_player_scaled','tb_memory_scale','tb_audio_visualizer','tb_audio_visualizer_link','tb_background_music','tb_background_music_link','tb_science_controls','tb_science_audio','tb_science_navigation','tb_science_scope','tb_science_display'))
$ErrorActionPreference='Stop'
if (-not $ModelSimBin) { $ModelSimBin=Split-Path (Get-Command vsim.exe -ErrorAction Stop).Source }
$root=Split-Path $PSScriptRoot
$hdl="$root/src/user_source/hdl_source"
$out=Join-Path $PSScriptRoot ('results/run_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path $out | Out-Null
Push-Location $out
try {
    if($Tests -contains 'tb_science_display') {
        python "$root/tools/prepare_science_sim.py" $out
        if($LASTEXITCODE) { throw 'science simulation asset preparation failed' }
    }
    & "$ModelSimBin/vlib.exe" work
    if($LASTEXITCODE) { throw 'vlib failed' }
    $files=@("$hdl/SD/bmp_read.v","$hdl/SD/bmp_scale_read.v","$hdl/SD/sd_card_bmp.v","$hdl/osd_overlay_640x480.v","$hdl/player_cdc.v","$hdl/video_fade_rgb.v")
    $files+=@("$hdl/SD/frame_fifo_read.v","$hdl/SD/frame_fifo_write.v")
    $files+=@("$hdl/player_audio_link.v","$hdl/I2S_receiver.v","$hdl/audio_visualizer.v","$hdl/background_music.v")
    $files+=@("$hdl/player_controls.v","$hdl/player_settings_osd.v","$hdl/video_picture_adjust.v")
    $files+=@(Get-ChildItem "$hdl/science_*.v" | ForEach-Object {$_.FullName})
    $files+=@(Get-ChildItem "$PSScriptRoot/tb_*.sv" | ForEach-Object {$_.FullName})
    & "$ModelSimBin/vlog.exe" -sv "+incdir+$hdl/include" @files 2>&1 | Tee-Object compile.log
    if($LASTEXITCODE) { throw 'vlog failed' }
    foreach($tb in $Tests) {
        if(-not (Test-Path "$PSScriptRoot/$tb.sv")) { throw "Missing testbench: $tb" }
        & "$ModelSimBin/vsim.exe" -c -onfinish stop "work.$tb" -do 'onerror {quit -code 1}; run -all; quit -code 0' 2>&1 | Tee-Object "$tb.log"
        if($LASTEXITCODE -or -not (Select-String -Path "$tb.log" -SimpleMatch "PASS $tb" -Quiet) -or
            (Select-String -Path "$tb.log" -Pattern '\*\* (Error|Fatal)' -Quiet)) { throw "$tb failed" }
    }
    Write-Output "SIMULATION_PASS=$out"
} finally { Pop-Location }
