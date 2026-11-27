# Changelog

All times CST.

## Docs — Nov 26, 2026, 11:30 PM
- Incident report rev 2.2: Thanksgiving updates (6.13): five confirmed past infections in a table (first OS 4 / X4 unit, first outside the US), staggered install times vs a single cleanup push, sshd_config rewritten at install, hardening suggestion, why logs rarely show the attack after restarts, unconfirmed local-account token theory.

## 1.13 — Nov 26, 2026, 11:20 PM
- Check 1.7: if the systemd journal starts after the attack window (usually because the controller restarted, which wipes a RAM-only journal), the report now says so, and a clean result reads **NO INDICATORS FOUND, BUT NO LOGS COVER THE ATTACK WINDOW** instead of a plain NO INDICATORS FOUND. Found from Zeyphod's CORE 5, whose journal started Nov 26.
- Collector 1.6: in the journal login list, logins from the PC running the collection are marked "(this PC)", so your own toolkit runs aren't mistaken for unknown access.
- README: how to download the files (Code → Download ZIP), after a run failed on a saved GitHub web page (issue #1).

## 1.12 — Nov 26, 2026, 1:50 PM
From muroglio's re-run on 4 controllers (thanks!):
- Check 1.6 and collector 1.5: **logs were never read on these units.** /var/log is a symlink to /var/volatile/log, and `find /var/log` doesn't follow it, so "Log files: none" and the c4diagd / 127.0.0.1 login counts were 0 without reading anything. Now uses `find /var/log/`, which does. **Anyone who got NO INDICATORS FOUND from check 1.3–1.5 should re-run.**
- "Oldest log file kept" used the file's modified time, which is "now" for an active log. Replaced with **Log coverage**: the first entry of each log file.
- "getty ALL COMMENTED OUT <-- review" showed on clean units too: it's the stock inittab on some OS versions. It is now only a warning when kit files are also found.
- "sshd STARTED BEFORE CONFIG CHANGE" stayed after `kill -HUP`, because a reload keeps the same PID and start time. Reworded as a note; the launcher's outside login-methods test is the real answer.

## 1.11 — Nov 26, 2026, 10:45 AM
- Check 1.5: reports when sshd_config last changed even if sshd isn't running, and flags a change between Nov 19 and 24. On every infected unit reported so far (CORE 1 on OS 4.2.1, CORE 5s, EA-5) the kit rewrote this file on Nov 22, and Control4's cleanup left it alone. On its own this gives POSSIBLE PAST INFECTION.
- Check 1.5: prints the active sshd_config settings so reports can be compared with clean units (thanks Zeyphod and diehardbattery732 for the first two).
- Check 1.5: new **Hardening suggestions** section, separate from the result: `PermitRootLogin yes` -> `prohibit-password` (suggested by rob____), `KbdInteractiveAuthentication` / `ChallengeResponseAuthentication yes` -> `no`, `PasswordAuthentication yes` -> `no`. `PermitRootLogin yes` is Control4's default, so it is not treated as a sign of infection.

## 1.10 — Nov 25, 2026, 11:20 PM
From LimitedLiabilities' second run (CORE 5, PREVIOUSLY INFECTED, found with rev 1.5):
- Check 1.4 and collector 1.4: also search the systemd journal and logs under /mnt/internal. The CORE 5 had no log files under /var/log, so the log checks had nothing to read.
- Launchers 1.6: when no saved key matches a controller, list the key folders tried and explain that each one is a controller MAC. If the controller's MAC isn't there, run the Jailbreak tool's SSH Access on it first.
- Windows launcher: ssh errors now show as plain text instead of PowerShell "NativeCommandError" blocks.

## 1.9 — Nov 25, 2026, 11:05 PM
From a field report by LimitedLiabilities (Windows, two jailbroken controllers), where every copy failed with "lost connection":
- Launchers 1.5 accept a key **folder** (e.g. the Jailbreak tool's `Keys - DO NOT DELETE`). They find the private keys inside, test each sub-folder against the controller without prompting, and use the one it accepts. A clear message is shown if none is accepted. Giving the folder used to make every login fail.
- First connection to a controller no longer stops at the yes/no host-key prompt (`StrictHostKeyChecking=accept-new`). A changed host key is still refused.
- scp no longer runs with `-q`, so the real ssh error is shown instead of just "lost connection".
- "keyboard-interactive" alone is no longer reported as PASSWORD LOGIN IS LIVE; it gets a softer note to check the sshd settings.
- Mac/Linux launcher avoids bash 4 features (macOS ships bash 3.2).

## Docs — Nov 25, 2026, 10:50 PM
- Incident report rev 2.1: evening updates (no new official information, conflicting OS 3.3.3 reports, two more confirmed past infections on OS 3.4.3, toolkit fixes for OS 3.4.x and jailbroken units); Finexus flagged as unreliable; homeowner sentiment; new section on community alternatives (7.7).

## 1.8 — Nov 25, 2026, 10:25 PM
- Windows launcher 1.4 and Mac/Linux launcher 1.4: if the controller only accepts key login and no key file was given, stop before copying and say so, with where to find the Jailbreak tool's key. Before, every step failed with a vague "lost connection" (reported in issue #2 by RollyandSam on a jailbroken CORE 5).
- The menu's key-file prompt now mentions the Jailbreak tool's key folder.
- README: second confirmed native Windows run (CORE 5, OS 3.4.3); key-login note.
- Windows test report template: added POSSIBLE PAST INFECTION, login method and toolkit revision.
- Guide rev 2.1 updated to match.

## 1.7 — Nov 25, 2026, 5:50 PM
Fixes from a field report by muroglio on an EA-5 (OS 3.4.3) that rev 1.2 wrongly reported as **NO INDICATORS FOUND**, although it was staged on Nov 22 and cleaned by Control4 on Nov 23.
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
