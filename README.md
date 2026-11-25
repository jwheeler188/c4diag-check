# c4diag-check

Read-only toolkit to check a Control4 controller for the **c4diagd / c4hijack** remote-lock kit found in November 2026, or to confirm a controller was cleaned up. It can also collect an evidence archive for Control4.

> **Community tool, not official Control4 guidance.** Based on community analysis of affected units. Use only on systems you own or are authorized to service.

## 🧪 Windows testers wanted

The Windows launcher (`c4diag-check.ps1`) has **not yet been run on a real Windows PC**. It has only been written and reviewed; development and testing so far were on Mac and Linux, and Windows under Parallels doesn't count as a native test.

If you can run it on a **native Windows 10 or 11 machine** (not a VM) against a controller you have root SSH on:

1. Run it in any mode (option 1, check only, is fine).
2. Open an issue using the **Windows test report** template: [New issue → Windows test report](../../issues/new?template=windows-test-report.md)
3. Include your Windows version, PowerShell version (`$PSVersionTable.PSVersion`), controller model/OS, which mode you used, whether it worked, and any errors. **Remove IPs, MACs and client names** from anything you paste.

Once a few native runs confirm it works, this notice will be removed.

## What's included

| File | Runs on | What it does |
|---|---|---|
| `c4diag-check.ps1` | Your Windows PC | Launcher with menu. Copies the controller scripts over SSH, runs them, saves reports. |
| `c4diag-run.sh` | Your Mac / Linux machine | Same launcher for Mac and Linux. |
| `c4diag-check.sh` | The controller | Read-only check. Prints NO INDICATORS, PREVIOUSLY INFECTED, INFECTED or ARMED. |
| `c4diag-collect.sh` | The controller | Gathers kit files, logs and settings into a hashed `.tar.gz` for Control4. |
| `docs/Control4_c4diagd_Infection_Check_Guide.pdf` | You | Full guide, including checks that need no controller access. |

**Keep all four scripts in the same folder.** The launchers only run on your computer; they copy the two controller scripts to the controller and run them there.

## Requirements

- Root SSH access to the controller (Control4 support, jailbroken units, or owners who kept SSH). Standard dealer-managed controllers do not give dealers root; for those, use the no-access checks in the guide (firewall logs, Toolbox → Patch Manager, controller snapshot).
- Windows 10/11 with the built-in OpenSSH client, or macOS / Linux with `ssh` and `scp`.

## Quick start

**Windows** (PowerShell, in the folder with the scripts):
```powershell
powershell -ExecutionPolicy Bypass -File .\c4diag-check.ps1
```

**Mac / Linux** (Terminal, in the folder with the scripts):
```bash
bash c4diag-run.sh
```

Both show a menu:

1. Check only
2. Check, and collect evidence if a current or past infection is found *(recommended)*
3. Check, and always collect evidence
4. Collect evidence only

Command-line options are in the guide and at the top of each launcher.

## Safety

- The check **never changes anything** on the controller. The recovery partition is mounted read-only (without journal replay) and unmounted afterwards.
- The check always runs first. If a unit shows **armed** indicators, evidence collection is skipped. **Do not reboot, kill processes or factory reset an armed unit.** Leave it alone and contact Control4.
- The collector refuses to run with less than 100 MB free in `/tmp` (which is RAM on controllers).
- Evidence archives may contain the **live malware binary**. Do not extract or run them on your computer. Send them to Control4 only through the channel they give you. They also contain client logs and network details.

## Indicators

Block at the firewall/DNS: `44.215.5.154`, `100.52.146.110`, `discfextnfkns.cloudfront.net`.
Do **not** block `13.217.247.30`, `98.80.86.147`, `firmware.testing.ovrc.com`, `13.59.208.61` or `18.220.45.107`; these appear to be legitimate Control4 infrastructure.

See the guide for the full list of on-controller indicators.

## Known limitations

See section 6.4 of the guide: log retention, other kit builds, recovery partition layout on some models, older OS tools, password prompts on Windows, host-key warnings.

## Credits

- Control4 DIY Unofficial Discord community for the original discovery and analysis.
- **TripleC** for spotting the masked-service false positive.

Analyst / maintainer: James Wheeler

## License

Released into the public domain under [The Unlicense](LICENSE). No warranty; use at your own risk.
