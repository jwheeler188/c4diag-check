# Changelog

All times CST.

## Docs — Nov 25, 2026, 1:05 PM
- Added the incident report (rev 1.7) to `docs/` so the latest revision is always in one place.

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
