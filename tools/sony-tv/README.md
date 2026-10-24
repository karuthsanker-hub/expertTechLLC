# Sony Bravia TV tune-up (ADB)

**Bottom line:** removes Sony and Google bloat for user 0 and shortens animations. No root, fully reversible with `restore`.

## Run in 3 commands

```bash
./sony-tv-tune.sh -t 192.168.1.50 audit       # see what's installed, edit packages.txt
./sony-tv-tune.sh -t 192.168.1.50 -n all      # dry run
./sony-tv-tune.sh -t 192.168.1.50 all         # debloat + speed
```

Undo: `./sony-tv-tune.sh -t 192.168.1.50 restore`

## TV prep

| Step | Where |
|---|---|
| Enable Developer options | Settings > System > About > tap **Build** 7 times |
| USB debugging on | Settings > System > Developer options |
| Network debugging on (if shown) | same menu; otherwise plug USB and run `adb tcpip 5555` once |
| Accept RSA prompt | on the TV, first time you connect |
| Install adb | macOS `brew install android-platform-tools`; Windows/Linux: Google platform-tools zip |

## What it changes

| Command | Action | Revert |
|---|---|---|
| `debloat` | `pm uninstall -k --user 0` for each installed package in `packages.txt`; logs to `removed-packages.log` | `restore` (`cmd package install-existing`) |
| `debloat -a` | also removes `?` lines (Google Assistant / voice search) | `restore` |
| `speed` | animation scales to 0.5 (`-s 0` for off) | `-s 1 speed` |
| `speed` | `pm trim-caches` | n/a, caches rebuild |
| `speed` | `cmd package bg-dexopt-job` (AOT compile now, 5 to 15 min) | n/a |

## Manual tweaks with the biggest payoff (not scriptable safely)

| Tweak | Where | Why |
|---|---|---|
| Leave Quick start ON (if your model has it) | Settings > Power | TV resumes from RAM instead of cold boot |
| Disable unused apps' auto-updates | Play Store > Settings | updates in background eat RAM/flash |
| Turn off "Usage & diagnostics" and Samba/Chromecast built-in if unused | Settings > Device Preferences | fewer background services |
| Swap launcher: Projectivy Launcher (Play Store), set as default in its settings | Play Store | stock Google TV home is the main source of lag |
| Keep >2 GB storage free | Settings > Storage | Bravia slows hard near full flash |

## Notes

- Package names vary by model and firmware year. The script skips anything not installed. Verify against `installed-packages.txt` after `audit` before adding to the list.
- Don't remove `com.sony.dtv.tvx`, `com.sony.dtv.tvinput.*`, launcher, or Play Services. Inputs, tuner, or the home screen break.
- A factory reset reinstates everything. A firmware update can too.

Exit codes: 0 ok, 1 usage, 2 adb/device, 3 one or more packages failed.
