param([string]$TdHome='D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116', [string]$ModelSimBin='')
$ErrorActionPreference='Stop'
if(-not $ModelSimBin){$ModelSimBin=Split-Path (Get-Command vsim.exe).Source}
$hdl=(Join-Path (Split-Path $PSScriptRoot) 'src/user_source/hdl_source').Replace('\','/')
$out=Join-Path $PSScriptRoot ('results/vendor_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path $out | Out-Null
Push-Location $out
try {
 & "$ModelSimBin/vlib.exe" work
 & "$ModelSimBin/vlog.exe" -sv "+incdir+$hdl/include" "$TdHome/sim_release/eg4/eg_phy_sdram_2m_32.v" "$hdl/include/sdr_init_ref.enc.v" "$hdl/include/sdr_wrrd.enc.v" "$hdl/include/sdr_as_ram.enc.v" "$hdl/SD/sdram.v" "$PSScriptRoot/vendor/tb_sdram.sv" 2>&1 | Tee-Object compile.log
 if($LASTEXITCODE){throw 'Vendor model compilation failed; no SDRAM simulation claim can be made.'}
 & "$ModelSimBin/vsim.exe" -c -onfinish stop work.tb_sdram -do 'run -all; quit -code 0' 2>&1 | Tee-Object test.log
 if($LASTEXITCODE -or -not (Select-String -Path test.log -SimpleMatch 'PASS tb_sdram' -Quiet) -or (Select-String -Path test.log -Pattern '\*\* (Error|Fatal)' -Quiet)){throw "Vendor SDRAM test failed. See $out"}
 Write-Output "VENDOR_SDRAM_PASS=$out"
} finally {Pop-Location}
