# Ender 3 V3 KE — Hybrid Restore

Halvautomatisk gjenoppretting av en factory-resatt Ender 3 V3 KE. Skriptet automatiserer alt som er trygt å automatisere; én manuell fase i midten der du velger features i Helper Script-menyen.

## Bruk

På printeren etter factory reset og root-aktivering:

```bash
wget -O- https://raw.githubusercontent.com/hauntedstack/Ender_3_V3_KE_restore_oneliner/main/install.sh | sh
```

## Hvorfor hybrid og ikke full one-liner?

Helper Script (Guilouz) er en interaktiv TUI uten CLI-modus. Et fullt automatisert skript måtte enten:

- bruke `expect` til å sende tastetrykk (bryter ved menyendringer i Helper Script), eller
- kalle interne shell-funksjoner direkte (bryter ved refaktorering)

Begge er skjøre. Hybrid-tilnærmingen er stabil over tid og krever bare ~30 sekunder manuell input.

## De 3 fasene

### Fase 1 — Automatisert forberedelse
- Verifiserer root, internett, Creality OS
- Kloner Helper Script til `/usr/data/helper-script`
- Laster ned config-filer (`printer.cfg`, `moonraker.conf`, `gcode_macro.cfg`) til `/usr/data/ke-restore-staging/`

### Fase 2 — Manuell features-installasjon
Skriptet starter Helper Script og viser deg en liste over hva som skal installeres:

```
[Install] menu:
  1. Moonraker and Nginx     ← installer FØRST
  2. Fluidd
  3. Mainsail
  4. KAMP
  5. M600 Support
  6. Save Z-Offset
  7. Improved Shapers
  8. Screws Tilt Adjust
  9. Useful Macros (valgfritt)
```

Du navigerer menyen, installerer features, trykker E for å avslutte.

### Fase 3 — Automatisert aktivering
- Verifiserer at nødvendige features ble installert
- Backer opp eksisterende configs til `pre-restore-backup-<timestamp>/`
- Kopierer staging-configs til `/usr/data/printer_data/config/`
- Restarter Klipper, Moonraker, Nginx via `supervisorctl`
- Viser kalibreringsoppskrift

## Etter installasjon — KRITISK kalibrering

Printeren har **ingen** kalibreringsdata. Du må kjøre disse i Fluidd-konsollen:

```
PROBE_CALIBRATE          # paper-test → ACCEPT
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

**ADVARSEL**: `z_offset: 0` i `printer.cfg` er placeholder. **Ikke print** før `PROBE_CALIBRATE` + `SAVE_CONFIG` er kjørt, ellers borer dyse ned i bed-en.

## Forutsetninger

- Firmware 1.1.0.12 eller nyere
- Factory reset utført (Settings → Restore Factory Settings)
- Root aktivert (Settings → Root Account Information → aksepter advarselen)
- Wi-Fi tilkoblet
- Stock Creality-grensesnitt ikke fjernet manuelt (skriptet erstatter det)

## Inkluderte configs

### `printer.cfg`
- Standard KE hardware (steppers, MCU, BLTouch, fans)
- Forbedret BLTouch (5 samples, tolerance 0.008, slow probe)
- 7×7 bicubic bed mesh
- `max_accel: 10000`
- Includes for Helper Script-features og KAMP
- `z_offset: 0` placeholder

### `gcode_macro.cfg`
- KAMP-aware `START_PRINT` (BED_MESH_CALIBRATE → SMART_PARK → LINE_PURGE)
- Custom `CANCEL_PRINT` med rask nedkjøling
- `BED_MESH_CALIBRATE_FAST` (adaptiv probe count)
- `BED_MESH_CHECK` validering
- `EJECT_PRINT` (skyver print av bed)
- M600 filament change
- Pause/resume

### `moonraker.conf`
- CORS for Fluidd, Mainsail
- Update_managers for Helper Script, Fluidd, Mainsail
- `enable_object_processing: True` (kreves av KAMP)

## Status

⚠️ **IKKE TESTET END-TO-END.** Skriptet er bygget basert på offisiell Helper Script-dokumentasjon (v5.0.0+) og verifisert mot Creality OS-strukturen, men har ikke blitt kjørt fra fersk factory reset til ferdig kalibrert printer ennå.

Kjente begrensninger:
- Service restart bruker `supervisorctl` (Supervisor Lite installeres med Moonraker fra Helper Script). Hvis Moonraker ikke installeres først, vil restart-kommandoer feile silent.
- Skriptet antar at brukeren faktisk velger de features som anbefales. Hopper du over `Save Z-Offset` for eksempel, vil Klipper krasje fordi `printer.cfg` inkluderer den filen.

Første gangs kjøring bør gjøres med åpen SSH-økt parallelt så du kan reagere på feil.

## Egen versjon

Fork repoet og overstyr peker med miljøvariabler:

```bash
KE_RESTORE_USER=dittnavn KE_RESTORE_REPO=ditt-repo sh install.sh
```

## Lisens

MIT
