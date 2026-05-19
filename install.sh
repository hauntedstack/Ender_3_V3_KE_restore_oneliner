#!/bin/sh
# =============================================================================
# Ender 3 V3 KE Hybrid Restore Script
# =============================================================================
# Bruker: wget -O- https://raw.githubusercontent.com/hauntedstack/Ender_3_V3_KE_restore_oneliner/main/install.sh | sh
#
# Forutsetninger:
#   - Printer er factory-resatt
#   - Root SSH er aktivert (Settings → Root Account Information)
#   - Tilkoblet til internett via Wi-Fi
#   - Firmware 1.1.0.12 eller nyere
#
# Workflow:
#   FASE 1 (auto):    Installer Helper Script, last ned configs
#   FASE 2 (manuell): Bruker kjører helper.sh og velger features via meny
#   FASE 3 (auto):    Last opp configs, restart tjenester
# =============================================================================

set -e

# -------- KONFIG --------
REPO_USER="${KE_RESTORE_USER:-hauntedstack}"
REPO_NAME="${KE_RESTORE_REPO:-Ender_3_V3_KE_restore_oneliner}"
REPO_BRANCH="${KE_RESTORE_BRANCH:-main}"
REPO_BASE_URL="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}"

PRINTER_DATA="/usr/data/printer_data"
CONFIG_DIR="${PRINTER_DATA}/config"
HELPER_SCRIPT_DIR="/usr/data/helper-script"
STAGING_DIR="/usr/data/ke-restore-staging"

# -------- COLOR OUTPUT --------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()      { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
success()  { printf "${GREEN}[OK]${NC}   %s\n" "$1"; }
warn()     { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error()    { printf "${RED}[ERR]${NC}  %s\n" "$1" >&2; }
fatal()    { error "$1"; exit 1; }
phase()    { printf "\n${BOLD}${CYAN}═══ %s ═══${NC}\n\n" "$1"; }

# -------- BANNER --------
cat <<'EOF'

  ╔══════════════════════════════════════════════════════════════╗
  ║       Ender 3 V3 KE Hybrid Restore Script                    ║
  ║       hauntedstack/Ender_3_V3_KE_restore_oneliner            ║
  ╚══════════════════════════════════════════════════════════════╝

  Dette skriptet kjører i 3 faser:
    FASE 1 (auto):    Installer Helper Script, last ned configs
    FASE 2 (manuell): Du velger features i Helper Script-menyen
    FASE 3 (auto):    Aktiver configs, restart tjenester

EOF

printf "Trykk Enter for å starte, Ctrl+C for å avbryte... "
read REPLY

# =============================================================================
# SJEKKER
# =============================================================================

if [ "$(id -u)" -ne 0 ]; then
    fatal "Dette skriptet må kjøres som root."
fi

if [ ! -d "/usr/data" ]; then
    fatal "Dette ser ikke ut som en Creality OS-printer. /usr/data finnes ikke."
fi

log "Sjekker internett-tilkobling..."
if ! ping -c 1 -W 5 github.com > /dev/null 2>&1; then
    fatal "Ingen internett-tilkobling. Sjekk Wi-Fi."
fi
success "Internett OK"

# =============================================================================
# FASE 1: AUTOMATISERT FORBEREDELSE
# =============================================================================
phase "FASE 1/3: Automatisert forberedelse"

# -------- Installer Helper Script --------
log "Installerer Creality Helper Script..."

if [ -d "$HELPER_SCRIPT_DIR" ]; then
    warn "Helper Script finnes allerede - oppdaterer istedenfor"
    cd "$HELPER_SCRIPT_DIR"
    git pull || warn "Kunne ikke oppdatere - fortsetter med eksisterende versjon"
else
    # Fix for SSL-feil som kan oppstå på enkelte firmware-versjoner
    git config --global http.sslVerify false 2>/dev/null || true

    git clone --depth 1 https://github.com/Guilouz/Creality-Helper-Script.git "$HELPER_SCRIPT_DIR" \
        || fatal "Klarte ikke å klone Helper Script"
fi

chmod +x "$HELPER_SCRIPT_DIR/helper.sh" 2>/dev/null || true
success "Helper Script installert i $HELPER_SCRIPT_DIR"

# -------- Last ned configs til staging --------
log "Laster ned config-filer til staging-mappe..."

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

CONFIG_FILES="printer.cfg moonraker.conf gcode_macro.cfg"
DOWNLOAD_FAILED=0

for f in $CONFIG_FILES; do
    if wget -q -O "$STAGING_DIR/$f" "${REPO_BASE_URL}/configs/${f}"; then
        success "Lastet ned $f"
    else
        error "Klarte ikke å laste ned $f"
        DOWNLOAD_FAILED=1
    fi
done

if [ $DOWNLOAD_FAILED -eq 1 ]; then
    warn "Noen filer feilet. Verifiser URL: ${REPO_BASE_URL}/configs/"
    printf "Fortsett likevel? [y/N]: "
    read REPLY
    case "$REPLY" in
        [Yy]*) ;;
        *) fatal "Avbrutt av bruker" ;;
    esac
fi

# =============================================================================
# FASE 2: MANUELL HELPER SCRIPT
# =============================================================================
phase "FASE 2/3: Manuell - velg features i Helper Script"

cat <<'EOF'

  Du skal nå kjøre Helper Script og velge følgende features:

  ┌─────────────────────────────────────────────────────────────┐
  │  ANBEFALTE INSTALLASJONER (i denne rekkefølgen)             │
  ├─────────────────────────────────────────────────────────────┤
  │                                                             │
  │  [Install] menu (1):                                        │
  │    1. Moonraker and Nginx     ← installer FØRST             │
  │    2. Fluidd                                                │
  │    3. Mainsail                                              │
  │    4. KAMP                                                  │
  │    5. M600 Support                                          │
  │    6. Save Z-Offset                                         │
  │    7. Improved Shapers                                      │
  │    8. Screws Tilt Adjust                                    │
  │    9. Useful Macros (valgfritt)                             │
  │                                                             │
  │  Trykk B etter hver installasjon for å gå tilbake.          │
  │  Trykk E for å avslutte Helper Script når ferdig.           │
  │                                                             │
  └─────────────────────────────────────────────────────────────┘

  Etter Helper Script avsluttes, fortsetter dette skriptet
  automatisk med FASE 3.

EOF

printf "Trykk Enter for å starte Helper Script... "
read REPLY

# Kjør Helper Script i interaktiv modus
sh "$HELPER_SCRIPT_DIR/helper.sh" || warn "Helper Script avsluttet med feilkode (kan være OK hvis du valgte E)"

# =============================================================================
# FASE 3: AKTIVER CONFIGS
# =============================================================================
phase "FASE 3/3: Aktiver configs og restart"

# -------- Verifiser at Helper Script-features ble installert --------
log "Verifiserer at nødvendige filer finnes..."

MISSING_FILES=""

check_file() {
    if [ ! -e "$1" ]; then
        MISSING_FILES="$MISSING_FILES\n  - $1"
    fi
}

check_file "${CONFIG_DIR}/Helper-Script/M600-support.cfg"
check_file "${CONFIG_DIR}/Helper-Script/save-zoffset.cfg"
check_file "${CONFIG_DIR}/Helper-Script/screws-tilt-adjust.cfg"

if [ -n "$MISSING_FILES" ]; then
    warn "Disse Helper Script-filene mangler:"
    printf "$MISSING_FILES\n"
    warn "Hvis include-linjer i printer.cfg refererer til disse, vil Klipper krasje."
    printf "Fortsett likevel? [y/N]: "
    read REPLY
    case "$REPLY" in
        [Yy]*) ;;
        *)
            log "Avbrutt. Du kan kjøre Helper Script igjen manuelt:"
            log "  sh $HELPER_SCRIPT_DIR/helper.sh"
            log "Configs ligger fortsatt i staging: $STAGING_DIR"
            log "Kjør deretter: sh $0 --resume"
            exit 0
            ;;
    esac
fi

# -------- Backup eksisterende configs --------
BACKUP_DIR="${CONFIG_DIR}/pre-restore-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
log "Tar backup av eksisterende configs til $BACKUP_DIR"

for f in $CONFIG_FILES; do
    if [ -e "${CONFIG_DIR}/${f}" ]; then
        cp "${CONFIG_DIR}/${f}" "$BACKUP_DIR/" || true
    fi
done
success "Backup tatt"

# -------- Kopier configs fra staging --------
log "Aktiverer nye configs..."

for f in $CONFIG_FILES; do
    if [ -e "$STAGING_DIR/$f" ]; then
        cp "$STAGING_DIR/$f" "${CONFIG_DIR}/$f"
        success "Aktivert $f"
    else
        warn "Hopper over $f (mangler i staging)"
    fi
done

# -------- Restart tjenester --------
log "Restarter tjenester..."

if command -v supervisorctl > /dev/null 2>&1; then
    supervisorctl restart klipper 2>/dev/null && success "Klipper restartet" || warn "Klipper-restart feilet"
    supervisorctl restart moonraker 2>/dev/null && success "Moonraker restartet" || warn "Moonraker-restart feilet"
    supervisorctl restart nginx 2>/dev/null && success "Nginx restartet" || warn "Nginx-restart feilet"
else
    warn "supervisorctl ikke funnet - prøver init.d"
    /etc/init.d/S55klipper_service restart 2>/dev/null || true
    /etc/init.d/S56moonraker_service restart 2>/dev/null || true
    /etc/init.d/S50nginx restart 2>/dev/null || true
fi

# -------- Rydd opp staging --------
rm -rf "$STAGING_DIR"

# =============================================================================
# FERDIG
# =============================================================================

PRINTER_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oE 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' | head -1)
PRINTER_IP=${PRINTER_IP:-<printer-ip>}

cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║                    INSTALLASJON FULLFØRT                     ║
╚══════════════════════════════════════════════════════════════╝

  Fluidd:   http://${PRINTER_IP}:4408
  Mainsail: http://${PRINTER_IP}:4409

  Backup av gamle configs: ${BACKUP_DIR}

═══ VIKTIG: KALIBRERING ═══

  Klipper kjører nå med dine configs, men har INGEN
  kalibreringsdata for denne fysiske printeren.

  Åpne Fluidd → konsollen og kjør i denne rekkefølgen:

  1. Z-OFFSET (KRITISK - må gjøres først):
     PROBE_CALIBRATE
     (gjør paper-test, trykk ACCEPT i Fluidd-popup)
     SAVE_CONFIG

  2. PID hotend (~5 min):
     PID_CALIBRATE HEATER=extruder TARGET=230
     SAVE_CONFIG

  3. PID bed (~10 min):
     PID_CALIBRATE HEATER=heater_bed TARGET=60
     SAVE_CONFIG

  4. Bed mesh (~3 min):
     M190 S60
     BED_MESH_CALIBRATE
     SAVE_CONFIG

  5. Input shaper (~5 min):
     SHAPER_CALIBRATE
     SAVE_CONFIG

  ADVARSEL: Z-offset er satt til 0 som placeholder.
  IKKE PRINT før du har kjørt PROBE_CALIBRATE!
  Nozzle vil ellers kjøre ned i bed-en.

═══ FEILSØKING ═══

  Hvis Klipper viser feil i Fluidd:
    - Sjekk klippy.log: tail -50 ${PRINTER_DATA}/logs/klippy.log
    - Vanlig feil: manglende include-fil (hoppet over en feature)
    - Rull tilbake: cp ${BACKUP_DIR}/* ${CONFIG_DIR}/

  Kjør Helper Script på nytt: sh ${HELPER_SCRIPT_DIR}/helper.sh

EOF
