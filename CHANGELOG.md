# Changelog

All times CST.

## 1.7 — Nov 25, 2026, 5:50 PM
Fixes from a field report on an EA-5 (OS 3.4.3) that rev 1.2 wrongly reported as **NO INDICATORS FOUND**, although it was staged on Nov 22 and cleaned by Control4 on Nov 23.
- Check 1.3 and collector 1.3: search all of `/var/log`, including `/var/log/debug/` (where OS 3.4.x keeps its logs), instead of only `/var/log/*`.
- Root's home is read from `/etc/passwd`; `/home/root/.ssh/authorized_keys` is now checked and collected.
- Root password logins from 127.0.0.1 (the Remote Access relay) are counted as past-infection evidence.
- Reports the times of `/usr/local`, `/usr/local/bin` and `/opt`. A change during Nov 19–24 with no other evidence gives a new result, **POSSIBLE PAST INFECTION (timestamps only)**, since an OS update that week can also cause it.
- Warns when `sshd_config` changed after sshd started (the running sshd may still accept passwords).
- "Files changed since Nov 15" uses `find -mtime` (BusyBox `touch -d` failed, so the list was empty). Patch check uses `dpkg -l` directly (`command -v dpkg` failed although dpkg works).
- The kit process is matched by exact name, so a command line that only mentions c4diagd no longer counts.
- Windows launcher 1.3 (`-IdentityFile`) and Mac/Linux launcher 1.3 (`-k`): log in with a private key for key-only controllers; the menu asks for it too.
- Both launchers test the running sshd from outside (`PreferredAuthentications=none`, no password sent) and flag **PASSWORD LOGIN IS LIVE**.
- Guide rev 2.0 updated to match.

## Docs — Nov 25, 2026, 5:05 PM
- Incident report rev 2.0: Control4's first official acknowledgement (dealer email) and ADI's statement to CE Pro; patch now reaching HC-800s; afternoon updates including a first report of a possibly armed EA-3.
- Guide rev 1.9: no-root patch check in Composer Pro (System Info → Packages); armed-unit ping symptom.

## Docs — Nov 25, 2026, 1:25 PM
- Incident report rev 1.9: HC-800 certificate patch routes (Control4 support Level 2 push; manual install on jailbroken units), patch failure troubleshooting, password-reset tip, and midday updates.
- Guide rev 1.8: HC-800 patch route and root-access patch check.

## Docs — Nov 25, 2026, 1:10 PM
- Incident report rev 1.8 and guide rev 1.7: GitHub link added to the first page and every footer so forwarded copies point back here.

## Docs — Nov 25, 2026, 1:05 PM
- Added the incident report to `docs/` so the latest revision is always in one place.

## 1.6 — Nov 25, 2026, 1:00 PM
- Windows launcher 1.2 and Mac/Linux launcher 1.2: newer OpenSSH clients make `scp` use SFTP, which controllers like the HC-800 don't support ("subsystem request failed"). Launchers now detect this and use classic scp (`-O`). Contributed by CK.
- Both launchers report a failed login clearly instead of saving an empty report, and stop cleanly if the collect script can't be copied.
- Windows launcher: refuses to run in PowerShell ISE (it can't take the SSH password) and labels each password prompt.
- Collector 1.2: recent-changes listing no longer runs `ls` per file (could take minutes after a large update).
- First confirmed Windows run (HC-800).

## 1.5 — Nov 25, 2026, 9:10 AM
- Check script 1.2: no longer counts Control4's "Maintain - c4diagd" cleanup log lines as infection (it ran on every controller, so nearly every unit looked infected).
- Check: no longer flags stock commented-out getty lines in `/etc/inittab` as armed.
- Check: rotated logs are no longer double-counted.
- Check and collector: recovery partition mounted read-only without journal replay.
- Check: reports how far back logs go, and lists unknown files, hidden folders and recent changes for review (other kit builds may use different names).
- Collector 1.1: checks free RAM in `/tmp` before collecting and limits how much it uses.
- Mac/Linux launcher 1.1: reuses one SSH connection, so the password is asked once.
- Guide: added known limitations.

## 1.4 — Nov 25, 2026, 9:00 AM
- Check script 1.1: a masked `c4diagd` (unit file linked to `/dev/null`) is reported as past infection, not active infection. Thanks to TripleC.

## 1.3 — Nov 25, 2026, 8:30 AM
- Added Mac/Linux launcher `c4diag-run.sh` and toolkit packaging.

## 1.2 — Nov 25, 2026, 8:25 AM
- Windows launcher shows a menu when run without options (check only, check + collect, collect only). Collection is skipped on units showing armed indicators.

## 1.1 — Nov 25, 2026, 8:20 AM
- Added Windows PowerShell launcher and evidence collector `c4diag-collect.sh`.

## 1.0 — Nov 25, 2026, 7:20 AM
- Initial guide and read-only check script.
