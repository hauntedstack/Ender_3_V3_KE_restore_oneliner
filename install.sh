#!/bin/sh
# =============================================================================
# Ender 3 V3 KE Full Restore Script
# =============================================================================
# Bruker: wget -O- https://raw.githubusercontent.com/hauntedstack/Ender_3_V3_KE_restore_oneliner/main/install.sh | sh
#
# Forutsetninger:
#   - Printer er factory-resatt
#   - Root SSH er aktivert (Settings → Root Account Information)
#   - Tilkoblet til internett via Wi-Fi
#
# Hva skriptet gjør:
#   1. Verifiserer at det kjører på en KE med root
#   2. Installerer Creality Helper Script
#   3. Installerer Moonraker, Fluidd, Mainsail
#   4. Installerer Helper Script features (M600, Save Z-offset, Improved Shapers, Screws Tilt)
#   5. Installerer KAMP manuelt
#   6. Kopierer config-filer fra repo (eller custom URL)
#   7. Restarter alt
#   8. Skriver ut kalibreringsoppskrift
# =============================================================================

set -e  # Exit on any error

# -------- KONFIG --------
REPO_USER="${KE_RESTORE_USER:-hauntedstack}"
REPO_NAME="${KE_RESTORE_REPO:-Ender_3_V3_KE_restore_oneliner}"
REPO_BRANCH="${KE_RESTORE_BRANCH:-main}"
REPO_BASE_URL="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}"

PRINTER_DATA="/usr/data/printer_data"
CONFIG_DIR="${PRINTER_DATA}/config"
HELPER_SCRIPT_DIR="/usr/data/helper-script"

# -------- COLOR OUTPUT --------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()      { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
success()  { printf "${GREEN}[OK]${NC}   %s\n" "$1"; }
warn()     { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error()    { printf "${RED}[ERR]${NC}  %s\n" "$1" >&2; }
fatal()    { error "$1"; exit 1; }

# -------- BANNER --------
cat <<'EOF'

  ╔══════════════════════════════════════════════════════════════╗
  ║       Ender 3 V3 KE Full Restore Script                      ║
  ║       Rosmo Digital — github.com/hauntedstack/Ender_3_V3_KE_restore_oneliner ║
  ╚══════════════════════════════════════════════════════════════╝

EOF

# -------- SJEKK 1: ER VI ROOT? --------
if [ "$(id -u)" -ne 0 ]; then
    fatal "Dette skriptet må kjøres som root. Prøv: sudo $0"
fi

# -------- SJEKK 2: ER DETTE EN KE? --------
if [ ! -d "/usr/data" ] || [ ! -f "/etc/creality_version" ] && [ ! -d "/usr/data/printer_data" ]; then
    warn "Kunne ikke detektere Creality OS. Fortsetter likevel - er du sikker dette er en KE?"
    printf "Trykk Enter for å fortsette, Ctrl+C for å avbryte... "
    read REPLY
fi

success "Kjører som root på Creality OS"

# -------- SJEKK 3: INTERNETT --------
log "Sjekker internett-tilkobling..."
if ! ping -c 1 -W 5 github.com > /dev/null 2>&1; then
    fatal "Ingen internett-tilkobling. Sjekk Wi-Fi-innstillinger på printeren."
fi
success "Internett OK"

# -------- VALG: HVOR SKAL CONFIGS KOMME FRA? --------
echo ""
log "Hvor skal config-filene komme fra?"
echo "  A) Bruk configs fra dette repoet (anbefalt)"
echo "  B) Bruk configs fra en custom URL"
echo "  C) Hopp over config-opplasting (kun installasjon av software)"
printf "Velg [A/B/C] (default A): "
read CONFIG_SOURCE
CONFIG_SOURCE=${CONFIG_SOURCE:-A}

CUSTOM_URL=""
if [ "$CONFIG_SOURCE" = "B" ] || [ "$CONFIG_SOURCE" = "b" ]; then
    printf "Lim inn base-URL (uten trailing slash, f.eks. https://example.com/myconfigs): "
    read CUSTOM_URL
    if [ -z "$CUSTOM_URL" ]; then
        fatal "Ingen URL angitt"
    fi
fi

# =============================================================================
# STEG 1: INSTALLER HELPER SCRIPT
# =============================================================================
echo ""
log "═══ STEG 1/5: Installerer Creality Helper Script ═══"

if [ -d "$HELPER_SCRIPT_DIR" ]; then
    warn "Helper Script finnes allerede - hopper over kloning"
else
    git clone --depth 1 https://github.com/Guilouz/Creality-Helper-Script.git "$HELPER_SCRIPT_DIR"
    success "Helper Script klonet"
fi

# =============================================================================
# STEG 2: INSTALLER MOONRAKER + FLUIDD + MAINSAIL
# =============================================================================
echo ""
log "═══ STEG 2/5: Installerer Moonraker, Fluidd, Mainsail ═══"

# Helper Script bruker interaktiv meny, så vi kaller install-scriptene direkte
HELPER_LIB="$HELPER_SCRIPT_DIR/files/scripts"

if [ ! -d "$HELPER_LIB" ]; then
    fatal "Helper Script struktur ser feil ut - $HELPER_LIB finnes ikke"
fi

# Moonraker + Nginx (kritisk - må være først)
log "Installerer Moonraker + Nginx..."
sh "$HELPER_LIB/moonraker_nginx.sh" install || warn "Moonraker-install returnerte feil, fortsetter..."

# Fluidd
log "Installerer Fluidd..."
sh "$HELPER_LIB/fluidd.sh" install || warn "Fluidd-install returnerte feil, fortsetter..."

# Mainsail
log "Installerer Mainsail..."
sh "$HELPER_LIB/mainsail.sh" install || warn "Mainsail-install returnerte feil, fortsetter..."

success "Web-frontends installert"

# =============================================================================
# STEG 3: INSTALLER HELPER SCRIPT FEATURES
# =============================================================================
echo ""
log "═══ STEG 3/5: Installerer features (M600, Save Z-offset, Improved Shapers, Screws Tilt) ═══"

# M600 Support
log "Installerer M600 Support..."
sh "$HELPER_LIB/m600_support.sh" install || warn "M600-install returnerte feil"

# Save Z-offset
log "Installerer Save Z-offset..."
sh "$HELPER_LIB/save_zoffset.sh" install || warn "Save Z-offset-install returnerte feil"

# Improved Shapers
log "Installerer Improved Shapers..."
sh "$HELPER_LIB/improved_shapers.sh" install || warn "Improved Shapers-install returnerte feil"

# Screws Tilt Adjust
log "Installerer Screws Tilt Adjust..."
sh "$HELPER_LIB/screws_tilt_adjust.sh" install || warn "Screws Tilt Adjust-install returnerte feil"

success "Features installert"

# =============================================================================
# STEG 4: INSTALLER KAMP MANUELT
# =============================================================================
echo ""
log "═══ STEG 4/5: Installerer KAMP (Klipper Adaptive Meshing & Purging) ═══"

cd /root

if [ -d "/root/Klipper-Adaptive-Meshing-Purging" ]; then
    warn "KAMP-repo finnes allerede - hopper over kloning"
else
    git clone https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging.git
fi

# Opprett ~/printer_data symlink hvis den ikke finnes (for kompatibilitet med standard KAMP-paths)
if [ ! -L "/root/printer_data" ] && [ ! -d "/root/printer_data" ]; then
    ln -s /usr/data/printer_data /root/printer_data
    success "Opprettet ~/printer_data symlink"
fi

# Opprett KAMP-symlink i config-mappa (overskriv hvis finnes)
rm -f "${CONFIG_DIR}/KAMP"
ln -s /root/Klipper-Adaptive-Meshing-Purging/Configuration "${CONFIG_DIR}/KAMP"
success "Opprettet KAMP-symlink"

success "KAMP installert"

# =============================================================================
# STEG 5: KOPIER CONFIGS
# =============================================================================
echo ""

if [ "$CONFIG_SOURCE" = "C" ] || [ "$CONFIG_SOURCE" = "c" ]; then
    warn "Hopper over config-opplasting (valgt av bruker)"
else
    log "═══ STEG 5/5: Kopierer config-filer ═══"

    # Bestem URL-base
    if [ -n "$CUSTOM_URL" ]; then
        URL_BASE="$CUSTOM_URL"
    else
        URL_BASE="${REPO_BASE_URL}/configs"
    fi

    # Backup eksisterende configs
    BACKUP_DIR="${CONFIG_DIR}/pre-restore-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    log "Tar backup av eksisterende configs til $BACKUP_DIR"
    cp "${CONFIG_DIR}/printer.cfg" "$BACKUP_DIR/" 2>/dev/null || true
    cp "${CONFIG_DIR}/moonraker.conf" "$BACKUP_DIR/" 2>/dev/null || true
    cp "${CONFIG_DIR}/gcode_macro.cfg" "$BACKUP_DIR/" 2>/dev/null || true
    cp "${CONFIG_DIR}/KAMP_Settings.cfg" "$BACKUP_DIR/" 2>/dev/null || true

    # Last ned nye configs
    for f in printer.cfg moonraker.conf gcode_macro.cfg KAMP_Settings.cfg; do
        log "Laster ned $f..."
        if wget -q -O "${CONFIG_DIR}/${f}" "${URL_BASE}/${f}"; then
            success "$f kopiert"
        else
            error "Klarte ikke å laste ned $f fra ${URL_BASE}/${f}"
            warn "Gjenoppretter backup..."
            cp "${BACKUP_DIR}/${f}" "${CONFIG_DIR}/${f}" 2>/dev/null || true
        fi
    done
fi

# =============================================================================
# RESTART KLIPPER
# =============================================================================
echo ""
log "Restarter Klipper og Moonraker..."

if command -v supervisorctl > /dev/null 2>&1; then
    supervisorctl restart klipper 2>/dev/null || true
    supervisorctl restart moonraker 2>/dev/null || true
    supervisorctl restart nginx 2>/dev/null || true
else
    /etc/init.d/S55klipper_service restart 2>/dev/null || true
    /etc/init.d/S56moonraker_service restart 2>/dev/null || true
    /etc/init.d/S50nginx restart 2>/dev/null || true
fi

success "Tjenester restartet"

# =============================================================================
# FERDIG - VIS KALIBRERINGSOPPSKRIFT
# =============================================================================
PRINTER_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oE 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' | head -1)
PRINTER_IP=${PRINTER_IP:-<printer-ip>}

cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║                    INSTALLASJON FULLFØRT                     ║
╚══════════════════════════════════════════════════════════════╝

  Fluidd:   http://${PRINTER_IP}:4408
  Mainsail: http://${PRINTER_IP}:4409

═══ NESTE STEG: KALIBRERING ═══

  Klipper kjører nå med dine configs, men har ingen
  kalibreringsdata for DENNE fysiske printeren ennå.

  Åpne Fluidd og kjør disse kommandoene i konsollen:

  1. Z-OFFSET:
     PROBE_CALIBRATE
     (gjør paper-test, deretter ACCEPT)
     SAVE_CONFIG

  2. PID hotend:
     PID_CALIBRATE HEATER=extruder TARGET=230
     SAVE_CONFIG

  3. PID bed:
     PID_CALIBRATE HEATER=heater_bed TARGET=60
     SAVE_CONFIG

  4. Bed mesh:
     M190 S60
     BED_MESH_CALIBRATE
     SAVE_CONFIG

  5. Input shaper:
     SHAPER_CALIBRATE
     SAVE_CONFIG

  Etter dette er printeren ferdig kalibrert og klar til print.

EOF
