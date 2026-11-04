param([string]$TdHome = $env:TD_HOME)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $TdHome) {
    $candidates = @(Get-ChildItem 'D:\Anlogic' -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'bin/td_commands_prompt.exe') })
    if ($candidates.Count -eq 1) { $TdHome = $candidates[0].FullName }
    else { throw 'Pass -TdHome pointing to the installed TD directory.' }
}
$td = Join-Path $TdHome 'bin/td_commands_prompt.exe'
if (-not (Test-Path $td)) { throw "TD executable not found: $td" }
$run = Join-Path $root ('build/run_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path "$run/syn", "$run/phy" | Out-Null
$projectDir = Join-Path $root 'src/td_project'
[xml]$project = (Get-Content (Join-Path $projectDir 'topic1_hdmi_player.al') -Raw -Encoding UTF8).Replace('P&R','P&amp;R')
$project.Project.RemoveAttribute('Path')
foreach ($file in $project.SelectNodes('//Source_Files//File[@Path]')) {
    $file.Path = [IO.Path]::GetFullPath((Join-Path $projectDir $file.Path)).Replace('\','/')
    if (-not (Test-Path -LiteralPath $file.Path)) { throw "Missing source: $($file.Path)" }
}
$hdl = (Join-Path $root 'src/user_source/hdl_source').Replace('\','/')
$constraints = (Join-Path $root 'src/user_source/constraints_source').Replace('\','/')
$base = @"
set ADCList [list {$constraints/pin.adc}]
set SDCList [list {$constraints/timing.sdc}]
set IpSDCList [list rfifo_32_32_512 {$hdl/ip/afifo_32_16_256.tcl} wfifo_32_32_512 {$hdl/ip/afifo_16_32_256.tcl}]
set area_option -packarea
set device_name eagle_s20.db
set package_name EG4S20BG256
set prj_name topic1_hdmi_player
set top_model_name top
"@
$env:TD_HOME = $TdHome.Replace('\','/')
$env:PLAYER_RUN_DIR = $run.Replace('\','/')
$sourceFiles = @(Get-ChildItem "$root/src/user_source", "$root/src/td_project/al_ip" -Recurse -File) +
    @(Get-Item "$root/src/td_project/topic1_hdmi_player.al")
$hashes = @($sourceFiles | Get-FileHash -Algorithm SHA256 | Select-Object Path,Hash)
$hashes | ConvertTo-Json -Depth 3 | Set-Content "$run/source_manifest.json" -Encoding UTF8
foreach ($stage in @('syn','phy')) {
    # TD's own project writer uses a literal '&' in UsedInP&R attributes.
    [IO.File]::WriteAllText("$run/$stage/topic1_hdmi_player.prj", $project.OuterXml.Replace('P&amp;R','P&R'))
    if ($stage -eq 'syn') {
        $extra = "`nset run_type syn`nset start_step read_design`nset end_step opt_gate`n"
    } else {
        $extra = "`nset run_type phy`nset start_step opt_place`nset end_step bitgen`nset parent ../syn`nset arr_filter false`nset drHoldFix on`n"
    }
    [IO.File]::WriteAllText("$run/$stage/settings.cfg", $base + $extra)
    $env:PLAYER_STAGE = $stage
    & $td ((Join-Path $root 'build_topic1.tcl').Replace('\','/')) 2>&1 | Tee-Object -FilePath "$run/$stage/build.log"
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$run/$stage/SUCCESS")) {
        throw "TD $stage failed. Inspect $run/$stage/build.log"
    }
}
$bit = "$run/phy/topic1_hdmi_player.bit"
if (-not (Test-Path $bit)) { throw 'No new bitstream produced.' }
# Keep outputs per run. Never overwrite the inherited output_bit file.
Get-FileHash $bit -Algorithm SHA256 | Format-List | Out-File "$run/bitstream_sha256.txt"
$timing = Get-Content "$run/phy/topic1_hdmi_player_pr.timing" -Raw
$setup = [regex]::Match($timing, 'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns')
$hold = [regex]::Match($timing, 'HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns')
if (-not $setup.Success -or -not $hold.Success) { throw 'Could not parse final timing report.' }
$culture = [Globalization.CultureInfo]::InvariantCulture
$setupWns = [double]::Parse($setup.Groups[1].Value,$culture)
$holdWns = [double]::Parse($hold.Groups[1].Value,$culture)
$changed = @($hashes | Where-Object { (Get-FileHash -LiteralPath $_.Path -Algorithm SHA256).Hash -ne $_.Hash })
$constraintErrors = @(Select-String -Path "$run/syn/build.log", "$run/phy/build.log" -Pattern 'USR-8159|CRITICAL-WARNING.*Command.*fail|ERROR.*(sdc|constraint)')
@{ buildCompleted=$true; setupWnsNs=$setupWns; holdWnsNs=$holdWns;
    timingPassed=($setupWns -ge 0 -and $holdWns -ge 0 -and $constraintErrors.Count -eq 0 -and $changed.Count -eq 0); hardwareTested=$false;
    constraintErrorCount=$constraintErrors.Count;
    sourceChangedDuringBuild=($changed.Count -ne 0); bitstream=$bit } |
    ConvertTo-Json | Set-Content "$run/validation.json" -Encoding UTF8
if ($changed.Count) { throw 'Sources changed during build; rebuild before using this result.' }
if ($constraintErrors.Count) { throw "Timing constraints failed to load. Inspect $run/*/build.log" }
Write-Output "BUILD_OUTPUT=$run"
if ($setupWns -lt 0 -or $holdWns -lt 0) {
    Write-Warning "TIMING NOT MET: setup WNS=$setupWns ns, hold WNS=$holdWns ns. Experimental bitstream only."
}
Write-Output 'Inspect phy/*timing and complete board tests before treating this bitstream as verified.'
