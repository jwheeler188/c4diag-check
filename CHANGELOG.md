# Changelog

All times CST.

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
