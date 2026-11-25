<#
.SYNOPSIS
  Runs the read-only c4diag-check.sh on one or more Control4 controllers from Windows
  and saves each report to a text file.

.DESCRIPTION
  Analyst: James Wheeler   Rev 1.1   November 25, 2026
  Requires the OpenSSH client built into Windows 10/11 (ssh and scp) and root SSH
  access to the controller. c4diag-check.sh must be in the same folder as this file.
  The check script only reads; this wrapper copies it to /tmp on the controller,
  runs it, saves the output here, and then deletes its own copy from /tmp.

  -Collect also runs c4diag-collect.sh (same folder) and downloads an evidence
  archive (.tar.gz) for Control4. Use -Collect Auto to collect only when the check
  finds an infection or past infection, or -Collect Always to collect every time.
  The archive may contain the live malware binary: do not extract or run it on a PC.

.EXAMPLE
  .\c4diag-check.ps1
  (no options: shows a menu that asks for the controller IP(s) and what to run)
.EXAMPLE
  .\c4diag-check.ps1 -Ip 192.168.1.50
.EXAMPLE
  .\c4diag-check.ps1 -Ip 192.168.1.50,192.168.1.51 -OutDir C:\Jobs\Smith
.EXAMPLE
  .\c4diag-check.ps1 -Ip 192.168.1.50 -Collect Auto
.EXAMPLE
  .\c4diag-check.ps1 -Ip 192.168.1.50 -CollectOnly
  (collect evidence without showing the full check; the check still runs first and
   collection is skipped if the unit looks armed)
.NOTES
  If Windows blocks the script, run:
  powershell -ExecutionPolicy Bypass -File .\c4diag-check.ps1 -Ip 192.168.1.50
#>
param(
    [string[]]$Ip,
    [string]$User = "root",
    [string]$OutDir = (Get-Location).Path,
    [string]$CheckScript = (Join-Path $PSScriptRoot "c4diag-check.sh"),
    [ValidateSet("None", "Auto", "Always")][string]$Collect = "None",
    [string]$CollectScript = (Join-Path $PSScriptRoot "c4diag-collect.sh"),
    [switch]$CollectOnly
)

# Continue (not Stop): in Windows PowerShell 5.1, Stop turns ssh/scp warnings on stderr into fatal errors.
$ErrorActionPreference = "Continue"

# Interactive menu when no controller IP was given
if (-not $Ip -or $Ip.Count -eq 0) {
    Write-Host ""
    Write-Host "Control4 c4diagd check  (James Wheeler, rev 1.1)" -ForegroundColor Cyan
    Write-Host "Everything here is read-only on the controller. You need root SSH access."
    Write-Host ""
    $entry = Read-Host "Controller IP address(es), separated by commas"
    $Ip = $entry -split "[,\s]+" | Where-Object { $_ -ne "" }
    if (-not $Ip) { Write-Host "No IP entered." -ForegroundColor Red; exit 1 }
    Write-Host ""
    Write-Host "What would you like to do?"
    Write-Host "  1) Check only (read-only report)"
    Write-Host "  2) Check, and collect evidence if an infection or past infection is found  [recommended]"
    Write-Host "  3) Check, and always collect evidence"
    Write-Host "  4) Collect evidence only (a quick check still runs first and stops if the unit looks armed)"
    $choice = Read-Host "Choose 1-4 [2]"
    switch ($choice) {
        "1" { $Collect = "None" }
        "3" { $Collect = "Always" }
        "4" { $Collect = "Always"; $CollectOnly = $true }
        default { $Collect = "Auto" }
    }
    $o = Read-Host "Folder for reports [$OutDir]"
    if ($o) { $OutDir = $o }
}
if ($CollectOnly -and $Collect -eq "None") { $Collect = "Always" }

foreach ($tool in "ssh", "scp") {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Host "$tool was not found. Install it in Settings > Apps > Optional features > OpenSSH Client." -ForegroundColor Red
        exit 1
    }
}
if (-not (Test-Path $CheckScript)) {
    Write-Host "Cannot find $CheckScript. Put c4diag-check.sh in the same folder as this file." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

if ($Collect -ne "None" -and -not (Test-Path $CollectScript)) {
    Write-Host "Cannot find $CollectScript. Put c4diag-collect.sh in the same folder as this file." -ForegroundColor Red
    exit 1
}

# Make copies with Linux (LF) line endings, in case the files were edited on Windows.
function New-LfCopy([string]$Source) {
    $text = [System.IO.File]::ReadAllText($Source) -replace "`r`n", "`n"
    $dest = Join-Path $env:TEMP ([System.IO.Path]::GetFileName($Source))
    [System.IO.File]::WriteAllText($dest, $text, (New-Object System.Text.UTF8Encoding($false)))
    return $dest
}
$lfCopy = New-LfCopy $CheckScript
$lfCollect = $null
if ($Collect -ne "None") { $lfCollect = New-LfCopy $CollectScript }

$remote = "/tmp/c4diag-check.sh"
$summary = @()

foreach ($target in $Ip) {
    $stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
    $report = Join-Path $OutDir ("c4diag-{0}-{1}.txt" -f $target, $stamp)
    Write-Host ""
    Write-Host "=== $target ===" -ForegroundColor Cyan

    & scp -q -o ConnectTimeout=10 $lfCopy "${User}@${target}:$remote"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Could not copy the script to $target (check the IP, network and SSH access)." -ForegroundColor Red
        $summary += [pscustomobject]@{ Controller = $target; Result = "NOT CHECKED (copy failed)"; Report = ""; Evidence = "" }
        continue
    }

    $output = & ssh -o ConnectTimeout=10 "${User}@${target}" "sh $remote; rm -f $remote" 2>&1 | ForEach-Object { "$_" }
    $output | Out-File -FilePath $report -Encoding utf8
    if (-not $CollectOnly) { $output | ForEach-Object { Write-Host $_ } }

    $result = "UNKNOWN (see report)"
    $color = "Yellow"
    $joined = ($output | Out-String)
    if     ($joined -match "ARMED / LOCKED INDICATORS FOUND")  { $result = "ARMED - do not reboot, escalate to Control4"; $color = "Red" }
    elseif ($joined -match "INFECTED \(staged\)")              { $result = "INFECTED (staged)"; $color = "Red" }
    elseif ($joined -match "PREVIOUSLY INFECTED, NOW CLEAN")   { $result = "PREVIOUSLY INFECTED, NOW CLEAN"; $color = "Yellow" }
    elseif ($joined -match "NO INDICATORS FOUND")              { $result = "NO INDICATORS FOUND"; $color = "Green" }

    Write-Host ""
    Write-Host "Result for ${target}: $result" -ForegroundColor $color
    Write-Host "Saved to $report"

    $evidence = ""
    $doCollect = ($Collect -eq "Always") -or ($Collect -eq "Auto" -and $result -match "INFECTED")
    if ($doCollect -and $result -like "ARMED*") {
        Write-Host "Evidence collection skipped: the unit shows armed indicators. Leave it untouched and escalate to Control4." -ForegroundColor Red
        $doCollect = $false
    }
    if ($doCollect) {
        Write-Host "Collecting evidence from $target ..." -ForegroundColor Cyan
        & scp -q -o ConnectTimeout=10 $lfCollect "${User}@${target}:/tmp/c4diag-collect.sh"
        $col = & ssh -o ConnectTimeout=10 "${User}@${target}" "sh /tmp/c4diag-collect.sh; rm -f /tmp/c4diag-collect.sh" 2>&1 | ForEach-Object { "$_" }
        $line = $col | Where-Object { $_ -like "ARCHIVE=*" } | Select-Object -Last 1
        if ($line) {
            $remoteArchive = $line.Substring(8).Trim()
            $local = Join-Path $OutDir ([System.IO.Path]::GetFileName($remoteArchive))
            & scp -q -o ConnectTimeout=10 "${User}@${target}:$remoteArchive" $local
            if ($LASTEXITCODE -eq 0 -and (Test-Path $local)) {
                & ssh -o ConnectTimeout=10 "${User}@${target}" "rm -f $remoteArchive" | Out-Null
                $hash = (Get-FileHash $local -Algorithm SHA256).Hash.ToLower()
                $col | Where-Object { $_ -match "^[0-9a-f]{64}\s" } | ForEach-Object { "Controller-side hash: $_" } | Out-File -FilePath "$local.sha256.txt" -Encoding utf8
                "PC-side SHA-256:      $hash" | Out-File -FilePath "$local.sha256.txt" -Encoding utf8 -Append
                Write-Host "Evidence saved to $local" -ForegroundColor Green
                Write-Host "SHA-256 $hash (recorded in $local.sha256.txt)"
                Write-Host "Do not extract or run this archive on a PC. Antivirus may quarantine it." -ForegroundColor Yellow
                $evidence = $local
            } else {
                Write-Host "Could not download $remoteArchive. It is still on the controller." -ForegroundColor Red
            }
        } else {
            Write-Host "Evidence collection did not produce an archive. Output:" -ForegroundColor Red
            $col | ForEach-Object { Write-Host $_ }
        }
    }
    $summary += [pscustomobject]@{ Controller = $target; Result = $result; Report = $report; Evidence = $evidence }
}

Remove-Item $lfCopy -ErrorAction SilentlyContinue
if ($lfCollect) { Remove-Item $lfCollect -ErrorAction SilentlyContinue }
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
$summary | Format-Table -AutoSize
