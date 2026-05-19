# Ender 3 V3 KE Full Restore

One-liner gjenoppretting av en factory-resatt Ender 3 V3 KE til full bruksklar tilstand med Helper Script, Fluidd, Mainsail, KAMP og custom configs.

## Bruk

### One-liner (anbefalt)

På printeren etter factory reset og root-aktivering:

```bash
wget -O- https://raw.githubusercontent.com/hauntedstack/Ender_3_V3_KE_restore_oneliner/main/install.sh | sh
```

### Manuelt

```bash
ssh root@<printer-ip>
wget https://raw.githubusercontent.com/hauntedstack/Ender_3_V3_KE_restore_oneliner/main/install.sh
chmod +x install.sh
./install.sh
```

## Hva skriptet gjør

1. **Verifiserer miljø** — sjekker root, Creality OS, internett
2. **Installerer Helper Script** (Guilouz) — `/usr/data/helper-script/`
3. **Installerer web-frontends** — Moonraker, Fluidd (port 4408), Mainsail (port 4409)
4. **Installerer features** — M600 Support, Save Z-offset, Improved Shapers, Screws Tilt Adjust
5. **Installerer KAMP** — `~/Klipper-Adaptive-Meshing-Purging/` + symlink i config
6. **Kopierer configs** — `printer.cfg`, `moonraker.conf`, `gcode_macro.cfg`, `KAMP_Settings.cfg`
7. **Restarter Klipper/Moonraker/Nginx**
8. **Skriver ut kalibreringsoppskrift**

## Hva skriptet IKKE gjør

Maskin-spesifikk kalibrering må kjøres manuelt etterpå, fordi hver KE er fysisk unik:

- **Z-offset** — `PROBE_CALIBRATE` + `SAVE_CONFIG`
- **PID hotend** — `PID_CALIBRATE HEATER=extruder TARGET=230` + `SAVE_CONFIG`
- **PID bed** — `PID_CALIBRATE HEATER=heater_bed TARGET=60` + `SAVE_CONFIG`
- **Bed mesh** — `BED_MESH_CALIBRATE` + `SAVE_CONFIG`
- **Input shaper** — `SHAPER_CALIBRATE` + `SAVE_CONFIG`

Skriptet skriver ut nøyaktige kommandoer ved slutten.

## Forutsetninger

- Printer er factory-resatt (Settings → Restore Factory Settings)
- Root er aktivert (Settings → Root Account Information → aksepter advarselen)
- Tilkoblet Wi-Fi
- Firmware 1.2.1.3 eller nyere

## Custom configs

Hvis du vil bruke dine egne configs istedenfor de i dette repoet, velg **B** når skriptet spør, og oppgi base-URL til en mappe som inneholder `printer.cfg`, `moonraker.conf`, `gcode_macro.cfg`, `KAMP_Settings.cfg`.

Eksempel:
```
https://raw.githubusercontent.com/dittnavn/mitt-ke-repo/main/configs
```

## Hva er inkludert i configs?

### `printer.cfg`
- Standard KE hardware-konfig (steppers, MCU, BLTouch, fans)
- Forbedret BLTouch-tuning (5 samples, tight tolerance, slow probe)
- 7×7 bicubic bed mesh
- `max_accel: 10000`
- Includes for Helper Script features og KAMP

### `gcode_macro.cfg`
- KAMP-aware `START_PRINT` (BED_MESH_CALIBRATE → SMART_PARK → LINE_PURGE)
- Custom `CANCEL_PRINT` med rask nedkjøling
- `BED_MESH_CALIBRATE_FAST` (adaptiv probe count)
- `BED_MESH_CHECK` (validering)
- `EJECT_PRINT` (skyver print av bed)
- M600 filament change
- Pause/resume-makroer

### `moonraker.conf`
- CORS for Fluidd, Mainsail
- Update_managers for Helper Script, Fluidd, Mainsail, KAMP

### `KAMP_Settings.cfg`
- Adaptive Meshing, Line Purge, Voron Purge, Smart Park aktivert

## Miljøvariabler

Du kan overstyre repo-pekeren før kjøring:

```bash
KE_RESTORE_USER=dittnavn KE_RESTORE_REPO=eget-repo sh install.sh
```

## Known Issues

Følgende punkter er ikke verifisert end-to-end og bør bekreftes mot din egen oppsett før produksjonsbruk:

- **Helper Script install-paths** er antatt å være `/usr/data/helper-script/files/scripts/` — skal verifiseres mot Guilouz' faktiske repo-struktur. Hvis Guilouz endrer mappestruktur kan `$HELPER_LIB`-pekeren i `install.sh` trenge oppdatering.
- **Non-interactive mode for Helper Script feature-installasjon** er antatt å fungere med `sh script.sh install`. Hvis install-scriptene venter på interaktiv input (y/n-bekreftelser), kan det være nødvendig å pipe `yes` inn, bruke `expect`, eller modifisere `$HELPER_LIB`-scriptene.
- **Service restart** bruker både `supervisorctl` og `init.d` som fallback — riktig variant er printer-firmware-versjonsavhengig. Begge er forsøkt for å dekke nyere og eldre Creality OS-versjoner.
- **Skriptet er IKKE testet end-to-end** på en fersk factory reset. Test i et trygt miljø før du stoler på det for en faktisk gjenoppretting.

## Lisens

MIT
