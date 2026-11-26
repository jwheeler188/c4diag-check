<#
.SYNOPSIS
  Runs the read-only c4diag-check.sh on one or more Control4 controllers from Windows
  and saves each report to a text file.

.DESCRIPTION
  Analyst: James Wheeler   Rev 1.6   November 25, 2026
  HC-800 / newer OpenSSH fixes contributed by CK (Control4 DIY Discord).
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
  .\c4diag-check.ps1 -Ip 192.168.1.50 -IdentityFile $HOME\.ssh\c4_ed25519
  (key-only SSH: log in with a private key file instead of a password)
.EXAMPLE
  .\c4diag-check.ps1 -Ip 192.168.1.50 -IdentityFile "C:\Tools\Control4.Jailbreak\Keys - DO NOT DELETE"
  (a folder also works: the launcher finds the keys in it and uses the ones the controller accepts)
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
    [string]$IdentityFile,
    [string]$OutDir = (Get-Location).Path,
    [string]$CheckScript = (Join-Path $PSScriptRoot "c4diag-check.sh"),
    [ValidateSet("None", "Auto", "Always")][string]$Collect = "None",
    [string]$CollectScript = (Join-Path $PSScriptRoot "c4diag-collect.sh"),
    [switch]$CollectOnly
)

# Continue (not Stop): in Windows PowerShell 5.1, Stop turns ssh/scp warnings on stderr into fatal errors.
$ErrorActionPreference = "Continue"

# ssh/scp cannot read a typed password in PowerShell ISE
if ($Host.Name -eq "Windows PowerShell ISE Host") {
    Write-Host "Run this from a normal PowerShell or Windows Terminal window, not PowerShell ISE (ISE cannot take the SSH password)." -ForegroundColor Red
    exit 1
}

# Interactive menu when no controller IP was given
if (-not $Ip -or $Ip.Count -eq 0) {
    Write-Host ""
    Write-Host "Control4 c4diagd check  (James Wheeler, rev 1.6)" -ForegroundColor Cyan
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
    $k = Read-Host "SSH key file or folder (blank = password; for jailbroken units enter the Jailbreak tool's 'Keys - DO NOT DELETE' folder)"
    if ($k) { $IdentityFile = $k.Trim('"') }
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
if ($IdentityFile -and -not (Test-Path $IdentityFile)) {
    Write-Host "Cannot find the key file or folder $IdentityFile." -ForegroundColor Red
    exit 1
}
# A key FOLDER is allowed (e.g. the Jailbreak tool's "Keys - DO NOT DELETE"): collect the private
# keys in it, grouped by sub-folder (one sub-folder per controller MAC), and later use the group
# each controller accepts.
$keyGroups = @()
$keyFolder = $false
if ($IdentityFile) {
    if (Test-Path $IdentityFile -PathType Container) {
        $keyFolder = $true
        $found = Get-ChildItem -Path $IdentityFile -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(ssh_host_.*_key|id_(rsa|ed25519|ecdsa))$' }
        if (-not $found) {
            Write-Host "No private keys (ssh_host_*_key or id_*) found in $IdentityFile." -ForegroundColor Red
            exit 1
        }
        foreach ($g in ($found | Group-Object DirectoryName)) {
            $keyGroups += ,@($g.Group | ForEach-Object { $_.FullName })
        }
        Write-Host ("Found {0} key file(s) in {1} folder(s) under {2}." -f @($found).Count, $keyGroups.Count, $IdentityFile)
    } else {
        $keyGroups += ,@((Resolve-Path $IdentityFile).Path)
    }
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

# Each ssh/scp call is its own login, so the password is asked more than once.
Write-Host ""
if ($IdentityFile) {
    Write-Host "Logging in with keys from $IdentityFile. If a key has a passphrase you will be asked for it at each login." -ForegroundColor Yellow
} elseif ($Collect -eq "None") {
    Write-Host "You will be asked for the root password 2 times per controller (copy, then run)." -ForegroundColor Yellow
} else {
    Write-Host "You will be asked for the root password 2 times per controller, plus 4 more if evidence is collected." -ForegroundColor Yellow
}
Write-Host "A new prompt after a step is normal. A wrong password shows 'Permission denied, please try again.'" -ForegroundColor Yellow
function Show-Step([string]$Text) { Write-Host "  -> $Text" -ForegroundColor DarkCyan }

# Newer OpenSSH makes scp use SFTP by default, which controllers do not have
# ("subsystem request failed"). -O switches back to the classic scp protocol when supported.
# accept-new: trust a controller's host key the first time without a yes/no prompt (a CHANGED
# key is still refused). No -q on scp, so real errors are shown instead of just "lost connection".
$baseOpts = @("-o", "ConnectTimeout=10", "-o", "StrictHostKeyChecking=accept-new")
$scpUsage = (& scp 2>&1 | Out-String)
$scpLegacy = $scpUsage -match "\[-[0-9A-Za-z]*O[0-9A-Za-z]*\]"

foreach ($target in $Ip) {
    $stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
    $report = Join-Path $OutDir ("c4diag-{0}-{1}.txt" -f $target, $stamp)
    Write-Host ""
    Write-Host "=== $target ===" -ForegroundColor Cyan

    # Ask the RUNNING sshd which login methods it offers (no login, no password sent).
    # sshd_config can say "no" while an sshd that was never restarted still accepts passwords.
    # ForEach "$_" turns PowerShell 5.1's NativeCommandError records back into plain ssh text
    $probe = (& ssh -o PreferredAuthentications=none -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR "${User}@${target}" exit 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $methods = ""
    $authLine = "Running sshd login methods (tested from this PC): unknown"
    if ($probe -match "Permission denied \(([^)]*)\)") {
        $methods = $Matches[1]
        $authLine = "Running sshd login methods (tested from this PC): $methods"
        if ($methods -match "password") { $authLine += "   <-- PASSWORD LOGIN IS LIVE (attacker enabled this; restart sshd after fixing sshd_config)" }
        elseif ($methods -match "keyboard-interactive") { $authLine += "   <-- keyboard-interactive offered (can allow password login; check PasswordAuthentication / KbdInteractiveAuthentication)" }
    }
    Write-Host $authLine -ForegroundColor $(if ($authLine -match "<--") { "Yellow" } else { "Gray" })

    # Jailbroken controllers usually accept key login only. Without a key file every login
    # would fail with a vague "lost connection", so stop here and say what to do.
    if (-not $IdentityFile -and $methods -and $methods -notmatch "password|keyboard-interactive") {
        Write-Host "$target only accepts key login (no passwords). Run again with -IdentityFile, or enter the key file in the menu." -ForegroundColor Red
        Write-Host "Jailbroken with the Control4 Jailbreak tool? Give its 'Keys - DO NOT DELETE' folder (or a key file inside it)." -ForegroundColor Yellow
        $summary += [pscustomobject]@{ Controller = $target; Result = "NOT CHECKED (key login required)"; Report = ""; Evidence = "" }
        continue
    }

    # Key folder: find the key set this controller accepts (BatchMode = no prompts), so a wrong
    # key shows a clear message instead of failing at the copy step. A single key file is used
    # as given (it may have a passphrase, which BatchMode cannot ask for).
    $sshOpts = @() + $baseOpts
    if ($keyGroups.Count -gt 0 -and -not $keyFolder) {
        $sshOpts += @("-o", "IdentitiesOnly=yes", "-i", $keyGroups[0][0])
    } elseif ($keyGroups.Count -gt 0) {
        $chosen = $null; $lastErr = ""
        foreach ($grp in $keyGroups) {
            $try = @() + $baseOpts + @("-o", "BatchMode=yes", "-o", "IdentitiesOnly=yes")
            foreach ($kf in $grp) { $try += @("-i", $kf) }
            $lastErr = ((& ssh @try "${User}@${target}" exit 2>&1 | ForEach-Object { "$_" }) -join " ").Trim()
            if ($LASTEXITCODE -eq 0) { $chosen = $grp; break }
        }
        if (-not $chosen) {
            Write-Host "None of the keys from $IdentityFile were accepted by $target." -ForegroundColor Red
            if ($lastErr) { Write-Host "ssh said: $lastErr" -ForegroundColor DarkGray }
            Write-Host ("Key folders tried: {0}" -f (($keyGroups | ForEach-Object { Split-Path (Split-Path $_[0] -Parent) -Leaf }) -join ", ")) -ForegroundColor DarkGray
            Write-Host "Each sub-folder of the Keys folder is one controller (named by MAC). If this controller's MAC isn't there, SSH was never set up for it from this PC:" -ForegroundColor Yellow
            Write-Host "run the Jailbreak tool's 'SSH Access' mode on it first (or use the Keys folder from the PC that did)." -ForegroundColor Yellow
            $summary += [pscustomobject]@{ Controller = $target; Result = "NOT CHECKED (no key accepted)"; Report = ""; Evidence = "" }
            continue
        }
        Write-Host ("Key accepted: {0}" -f (Split-Path $chosen[0] -Parent)) -ForegroundColor Gray
        $sshOpts += @("-o", "IdentitiesOnly=yes")
        foreach ($kf in $chosen) { $sshOpts += @("-i", $kf) }
    }
    $scpOpts = @() + $sshOpts
    if ($scpLegacy) { $scpOpts += "-O" }

    Show-Step "Login 1 of 2: copying the check script"
    & scp @scpOpts $lfCopy "${User}@${target}:$remote"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Could not copy the script to $target (check the IP, network, password and SSH access)." -ForegroundColor Red
        $summary += [pscustomobject]@{ Controller = $target; Result = "NOT CHECKED (copy failed)"; Report = ""; Evidence = "" }
        continue
    }

    Show-Step "Login 2 of 2: running the check"
    $output = & ssh @sshOpts "${User}@${target}" "sh $remote; rm -f $remote" 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -eq 255) {
        $output | ForEach-Object { Write-Host $_ }
        Write-Host "Could not log in to $target to run the check. The copy in $remote was left on the controller." -ForegroundColor Red
        $summary += [pscustomobject]@{ Controller = $target; Result = "NOT CHECKED (login failed)"; Report = ""; Evidence = "" }
        continue
    }
    @($authLine, "") + $output | Out-File -FilePath $report -Encoding utf8
    if (-not $CollectOnly) { $output | ForEach-Object { Write-Host $_ } }

    $result = "UNKNOWN (see report)"
    $color = "Yellow"
    $joined = ($output | Out-String)
    if     ($joined -match "ARMED / LOCKED INDICATORS FOUND")  { $result = "ARMED - do not reboot, escalate to Control4"; $color = "Red" }
    elseif ($joined -match "INFECTED \(staged\)")              { $result = "INFECTED (staged)"; $color = "Red" }
    elseif ($joined -match "PREVIOUSLY INFECTED, NOW CLEAN")   { $result = "PREVIOUSLY INFECTED, NOW CLEAN"; $color = "Yellow" }
    elseif ($joined -match "POSSIBLE PAST INFECTION")          { $result = "POSSIBLE PAST INFECTION (timestamps only)"; $color = "Yellow" }
    elseif ($joined -match "NO INDICATORS FOUND")              { $result = "NO INDICATORS FOUND"; $color = "Green" }

    Write-Host ""
    Write-Host "Result for ${target}: $result" -ForegroundColor $color
    Write-Host "Saved to $report"

    $evidence = ""
    $doCollect = ($Collect -eq "Always") -or ($Collect -eq "Auto" -and $result -match "INFECT")
    if ($doCollect -and $result -like "ARMED*") {
        Write-Host "Evidence collection skipped: the unit shows armed indicators. Leave it untouched and escalate to Control4." -ForegroundColor Red
        $doCollect = $false
    }
    if ($doCollect) {
        Write-Host "Collecting evidence from $target ..." -ForegroundColor Cyan
        Show-Step "Evidence login 1 of 4: copying the collect script"
        & scp @scpOpts $lfCollect "${User}@${target}:/tmp/c4diag-collect.sh"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Could not copy the collect script to $target. No evidence collected." -ForegroundColor Red
            $summary += [pscustomobject]@{ Controller = $target; Result = $result; Report = $report; Evidence = "" }
            continue
        }
        Show-Step "Evidence login 2 of 4: running the collection"
        $col = & ssh @sshOpts "${User}@${target}" "sh /tmp/c4diag-collect.sh; rm -f /tmp/c4diag-collect.sh" 2>&1 | ForEach-Object { "$_" }
        $line = $col | Where-Object { $_ -like "ARCHIVE=*" } | Select-Object -Last 1
        if ($line) {
            $remoteArchive = $line.Substring(8).Trim()
            $local = Join-Path $OutDir ([System.IO.Path]::GetFileName($remoteArchive))
            Show-Step "Evidence login 3 of 4: downloading the archive"
            & scp @scpOpts "${User}@${target}:$remoteArchive" $local
            if ($LASTEXITCODE -eq 0 -and (Test-Path $local)) {
                Show-Step "Evidence login 4 of 4: removing the archive from the controller"
                & ssh @sshOpts "${User}@${target}" "rm -f $remoteArchive" | Out-Null
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
