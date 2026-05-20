# Ender 3 V3 KE — Hybrid Restore

Semi-automated recovery of a factory-reset Ender 3 V3 KE. The script automates everything that's safe to automate; one manual phase in the middle where you pick features from the Helper Script menu.

## Usage

On the printer after factory reset and root activation:

```bash
wget -O- https://raw.githubusercontent.com/hauntedstack/Ender_3_V3_KE_restore_oneliner/main/install.sh | sh
```

## Why hybrid instead of a full one-liner?

Helper Script (Guilouz) is an interactive TUI with no CLI mode. A fully automated script would have to either:

- use `expect` to send keystrokes (breaks whenever Helper Script changes its menus), or
- call its internal shell functions directly (breaks on refactors)

Both are fragile. The hybrid approach stays stable over time and only takes ~30 seconds of manual input.

## The 3 phases

### Phase 1 — Automated preparation
- Verifies root, internet, Creality OS
- Clones Helper Script to `/usr/data/helper-script`
- Downloads config files (`printer.cfg`, `moonraker.conf`, `gcode_macro.cfg`) to `/usr/data/ke-restore-staging/`

### Phase 2 — Manual feature installation
The script launches Helper Script and shows you a list of what to install:

```
[Install] menu:
  1. Moonraker and Nginx     ← install FIRST
  2. Fluidd
  3. Mainsail
  4. KAMP
  5. M600 Support
  6. Save Z-Offset
  7. Improved Shapers
  8. Screws Tilt Adjust
  9. Useful Macros (optional)
```

Navigate the menu, install features, press E to exit.

### Phase 3 — Automated activation
- Verifies that the required features were installed
- Backs up existing configs to `pre-restore-backup-<timestamp>/`
- Copies staging configs to `/usr/data/printer_data/config/`
- Restarts Klipper, Moonraker, Nginx via `supervisorctl`
- Prints the calibration recipe

## After installation — CRITICAL calibration

The printer has **no** calibration data yet. You must run these in the Fluidd console:

```
PROBE_CALIBRATE          # paper test → ACCEPT
SAVE_CONFIG

PID_CALIBRATE HEATER=extruder TARGET=230
SAVE_CONFIG

PID_CALIBRATE HEATER=heater_bed TARGET=60
SAVE_CONFIG

M190 S60
BED_MESH_CALIBRATE
SAVE_CONFIG

SHAPER_CALIBRATE
SAVE_CONFIG
```

**WARNING**: `z_offset: 0` in `printer.cfg` is a placeholder. **Do not print** until `PROBE_CALIBRATE` + `SAVE_CONFIG` has been run, or the nozzle will drive into the bed.

## Prerequisites

- Firmware 1.1.0.12 or newer
- Factory reset performed (Settings → Restore Factory Settings)
- Root enabled (Settings → Root Account Information → accept the warning)
- Connected to Wi-Fi
- Stock Creality interface not manually removed (the script replaces it)

## Included configs

### `printer.cfg`
- Standard KE hardware (steppers, MCU, BLTouch, fans)
- Improved BLTouch (5 samples, tolerance 0.008, slow probe)
- 7×7 bicubic bed mesh
- `max_accel: 10000`
- Includes for Helper Script features and KAMP
- `z_offset: 0` placeholder

### `gcode_macro.cfg`
- KAMP-aware `START_PRINT` (BED_MESH_CALIBRATE → SMART_PARK → LINE_PURGE)
- Custom `CANCEL_PRINT` with rapid cooldown
- `BED_MESH_CALIBRATE_FAST` (adaptive probe count)
- `BED_MESH_CHECK` validation
- `EJECT_PRINT` (pushes the print off the bed)
- `SAFE_EXTRUDE` (progressive extrusion with Z-lift)
- M600 filament change
- Pause/resume

### `moonraker.conf`
- CORS for Fluidd, Mainsail
- Update_managers for Helper Script, Fluidd, Mainsail
- `enable_object_processing: True` (required by KAMP)

## OrcaSlicer configuration

This repo contains the Klipper-side configs. The slicer side (OrcaSlicer Start/End G-code, bed shape) is configured separately on your PC.

### Bed Shape

**Printer Settings → Printable Area:**
- Shape: Rectangular
- Size: X=221, Y=221 (slightly over the physical 220 to avoid false-positive boundary warnings)
- Origin: X=0, Y=0

### Recommended Machine Start G-code

Optimized for KAMP and minimal wait time between prints (no unnecessary pre-heat phase):

```
; Ender 3 V3 KE Custom Start G-code (KAMP-optimized)
M140 S[bed_temperature_initial_layer_single]   ; Start heating bed
M190 S[bed_temperature_initial_layer_single]   ; Wait for bed
M400
G28                                            ; Home
BED_MESH_CALIBRATE                             ; Adaptive mesh (KAMP overrides to adaptive)
SMART_PARK                                     ; Park near print area (KAMP)
M109 S[nozzle_temperature_initial_layer]       ; Heat to print temp
G92 E0
LINE_PURGE                                     ; Adaptive purge line (KAMP)
```

**Why no pre-heat?** The usual "pre-heat to 150°C before probing" is often cargo-cult. On the KE with BLTouch (mechanical probe), the only real reason would be filament ooze during probing. KAMP's `LINE_PURGE` cleans that up anyway, so there's no real effect on the print. Saves ~2 minutes per print on back-to-back jobs with a hot hotend.

### Recommended Machine End G-code

```
G91                  ; Relative positioning
G1 F1800 E-6         ; Retract 6mm
G1 F600 Z5           ; Lift Z 5mm
G90                  ; Back to absolute
G1 X0 Y215 F7200     ; Move bed forward (Y=215, not 220, to avoid boundary warning)
M84                  ; Disable steppers
```

### IMPORTANT: NEVER use ADAPTIVE_BED_MESH_CALIBRATE

This is NOT a valid command. KAMP automatically overrides the standard `BED_MESH_CALIBRATE` when `Adaptive_Meshing.cfg` is enabled. Always use `BED_MESH_CALIBRATE`.

## Status

⚠️ **NOT TESTED END-TO-END.** The script is built from the official Helper Script docs (v5.0.0+) and verified against the Creality OS layout, but it has not been run from a fresh factory reset through to a fully calibrated printer.

Known limitations:
- Service restart uses `supervisorctl` (Supervisor Lite is installed alongside Moonraker by Helper Script). If Moonraker isn't installed first, the restart commands will fail silently.
- The script assumes you actually pick the recommended features. Skipping e.g. `Save Z-Offset` will crash Klipper, because `printer.cfg` includes that file.

The first run should be done with an SSH session open in parallel so you can react to errors.

## Your own version

Fork the repo and override the pointer via environment variables:

```bash
KE_RESTORE_USER=yourname KE_RESTORE_REPO=your-repo sh install.sh
```

## License

MIT
