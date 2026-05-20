#!/bin/sh
# =============================================================================
# Ender 3 V3 KE Hybrid Restore Script
# =============================================================================
# Usage: wget -O- https://raw.githubusercontent.com/hauntedstack/Ender_3_V3_KE_restore_oneliner/main/install.sh | sh
#
# Prerequisites:
#   - Printer is factory-reset
#   - Root SSH is enabled (Settings → Root Account Information)
#   - Connected to internet via Wi-Fi
#   - Firmware 1.1.0.12 or newer
#
# Workflow:
#   PHASE 1 (auto):    Install Helper Script, download configs
#   PHASE 2 (manual):  User runs helper.sh and selects features from the menu
#   PHASE 3 (auto):    Activate configs, restart services
# =============================================================================

set -e

# -------- CONFIG --------
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

  This script runs in 3 phases:
    PHASE 1 (auto):    Install Helper Script, download configs
    PHASE 2 (manual):  You select features in the Helper Script menu
    PHASE 3 (auto):    Activate configs, restart services

EOF

printf "Press Enter to start, Ctrl+C to abort... "
read REPLY

# =============================================================================
# CHECKS
# =============================================================================

if [ "$(id -u)" -ne 0 ]; then
    fatal "This script must be run as root."
fi

if [ ! -d "/usr/data" ]; then
    fatal "This does not look like a Creality OS printer. /usr/data does not exist."
fi

log "Checking internet connection..."
if ! ping -c 1 -W 5 github.com > /dev/null 2>&1; then
    fatal "No internet connection. Check Wi-Fi."
fi
success "Internet OK"

# =============================================================================
# PHASE 1: AUTOMATED PREPARATION
# =============================================================================
phase "PHASE 1/3: Automated preparation"

# -------- Install Helper Script --------
log "Installing Creality Helper Script..."

if [ -d "$HELPER_SCRIPT_DIR" ]; then
    warn "Helper Script already exists - updating instead"
    cd "$HELPER_SCRIPT_DIR"
    git pull || warn "Could not update - continuing with existing version"
else
    # Workaround for SSL errors that occur on some firmware versions
    git config --global http.sslVerify false 2>/dev/null || true

    git clone --depth 1 https://github.com/Guilouz/Creality-Helper-Script.git "$HELPER_SCRIPT_DIR" \
        || fatal "Failed to clone Helper Script"
fi

chmod +x "$HELPER_SCRIPT_DIR/helper.sh" 2>/dev/null || true
success "Helper Script installed in $HELPER_SCRIPT_DIR"

# -------- Download configs to staging --------
log "Downloading config files to staging directory..."

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

CONFIG_FILES="printer.cfg moonraker.conf gcode_macro.cfg"
DOWNLOAD_FAILED=0

for f in $CONFIG_FILES; do
    if wget -q -O "$STAGING_DIR/$f" "${REPO_BASE_URL}/configs/${f}"; then
        success "Downloaded $f"
    else
        error "Failed to download $f"
        DOWNLOAD_FAILED=1
    fi
done

if [ $DOWNLOAD_FAILED -eq 1 ]; then
    warn "Some files failed. Verify URL: ${REPO_BASE_URL}/configs/"
    printf "Continue anyway? [y/N]: "
    read REPLY
    case "$REPLY" in
        [Yy]*) ;;
        *) fatal "Aborted by user" ;;
    esac
fi

# =============================================================================
# PHASE 2: MANUAL HELPER SCRIPT
# =============================================================================
phase "PHASE 2/3: Manual - select features in Helper Script"

cat <<'EOF'

  You will now run Helper Script and install the following features:

  ┌─────────────────────────────────────────────────────────────┐
  │  RECOMMENDED INSTALLATIONS (in this order)                  │
  ├─────────────────────────────────────────────────────────────┤
  │                                                             │
  │  [Install] menu (1):                                        │
  │    1. Moonraker and Nginx     ← install FIRST               │
  │    2. Fluidd                                                │
  │    3. Mainsail                                              │
  │    4. KAMP                                                  │
  │    5. M600 Support                                          │
  │    6. Save Z-Offset                                         │
  │    7. Improved Shapers                                      │
  │    8. Screws Tilt Adjust                                    │
  │    9. Useful Macros (optional)                              │
  │                                                             │
  │  Press B after each install to return to the previous menu. │
  │  Press E to exit Helper Script when finished.               │
  │                                                             │
  └─────────────────────────────────────────────────────────────┘

  After Helper Script exits, this script will automatically
  continue with PHASE 3.

EOF

printf "Press Enter to launch Helper Script... "
read REPLY

# Run Helper Script in interactive mode
sh "$HELPER_SCRIPT_DIR/helper.sh" || warn "Helper Script exited with non-zero code (may be OK if you chose E)"

# =============================================================================
# PHASE 3: ACTIVATE CONFIGS
# =============================================================================
phase "PHASE 3/3: Activate configs and restart"

# -------- Verify Helper Script features were installed --------
log "Verifying that required files exist..."

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
    warn "These Helper Script files are missing:"
    printf "$MISSING_FILES\n"
    warn "If include lines in printer.cfg reference these, Klipper will crash."
    printf "Continue anyway? [y/N]: "
    read REPLY
    case "$REPLY" in
        [Yy]*) ;;
        *)
            log "Aborted. You can run Helper Script again manually:"
            log "  sh $HELPER_SCRIPT_DIR/helper.sh"
            log "Configs are still in staging: $STAGING_DIR"
            log "Then run: sh $0 --resume"
            exit 0
            ;;
    esac
fi

# -------- Back up existing configs --------
BACKUP_DIR="${CONFIG_DIR}/pre-restore-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
log "Backing up existing configs to $BACKUP_DIR"

for f in $CONFIG_FILES; do
    if [ -e "${CONFIG_DIR}/${f}" ]; then
        cp "${CONFIG_DIR}/${f}" "$BACKUP_DIR/" || true
    fi
done
success "Backup complete"

# -------- Copy configs from staging --------
log "Activating new configs..."

for f in $CONFIG_FILES; do
    if [ -e "$STAGING_DIR/$f" ]; then
        cp "$STAGING_DIR/$f" "${CONFIG_DIR}/$f"
        success "Activated $f"
    else
        warn "Skipping $f (missing in staging)"
    fi
done

# -------- Restart services --------
log "Restarting services..."

if command -v supervisorctl > /dev/null 2>&1; then
    supervisorctl restart klipper 2>/dev/null && success "Klipper restarted" || warn "Klipper restart failed"
    supervisorctl restart moonraker 2>/dev/null && success "Moonraker restarted" || warn "Moonraker restart failed"
    supervisorctl restart nginx 2>/dev/null && success "Nginx restarted" || warn "Nginx restart failed"
else
    warn "supervisorctl not found - trying init.d"
    /etc/init.d/S55klipper_service restart 2>/dev/null || true
    /etc/init.d/S56moonraker_service restart 2>/dev/null || true
    /etc/init.d/S50nginx restart 2>/dev/null || true
fi

# -------- Clean up staging --------
rm -rf "$STAGING_DIR"

# =============================================================================
# DONE
# =============================================================================

PRINTER_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oE 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' | head -1)
PRINTER_IP=${PRINTER_IP:-<printer-ip>}

cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║                  INSTALLATION COMPLETE                       ║
╚══════════════════════════════════════════════════════════════╝

  Fluidd:   http://${PRINTER_IP}:4408
  Mainsail: http://${PRINTER_IP}:4409

  Backup of old configs: ${BACKUP_DIR}

═══ IMPORTANT: CALIBRATION ═══

  Klipper is now running with your configs, but has NO
  calibration data for this physical printer yet.

  Open Fluidd → console and run, in this order:

  1. Z-OFFSET (CRITICAL - must be done first):
     PROBE_CALIBRATE
     (do the paper test, press ACCEPT in the Fluidd popup)
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

  WARNING: Z-offset is set to 0 as a placeholder.
  DO NOT PRINT until you have run PROBE_CALIBRATE!
  The nozzle will otherwise drive into the bed.

═══ TROUBLESHOOTING ═══

  If Klipper shows errors in Fluidd:
    - Check klippy.log: tail -50 ${PRINTER_DATA}/logs/klippy.log
    - Common error: missing include file (skipped a feature)
    - Roll back: cp ${BACKUP_DIR}/* ${CONFIG_DIR}/

  Run Helper Script again: sh ${HELPER_SCRIPT_DIR}/helper.sh

EOF
