#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  Brain Shell — NixOS Installer
#  Invoked by install.sh:  $1=HYPRLAND_CONF  $2=BACKUP_DIR  $3=CONFIG_TYPE
# ─────────────────────────────────────────────────────────────────────────────

set -eo pipefail

HYPRLAND_CONF="${1:?Missing arg: HYPRLAND_CONF path}"
BACKUP_DIR="${2:?Missing arg: BACKUP_DIR}"
CONFIG_TYPE="${3:?Missing arg: CONFIG_TYPE (conf|lua)}"
REPO_DIR="$HOME/.local/src/Brain_Shell"

RED='\033[0;31m';   GREEN='\033[0;32m';  YELLOW='\033[1;33m'
BLUE='\033[0;34m';  CYAN='\033[0;36m';   BOLD='\033[1m'
DIM='\033[2m';      NC='\033[0m'

log_info()  { echo -e "  ${BLUE}·${NC} $1"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }

TOTAL_STEPS=3
step() {
    echo ""
    echo -e "${BOLD}${CYAN}  [$1/$TOTAL_STEPS]  $2${NC}"
    echo -e "  ${DIM}$(printf '%.0s─' {1..50})${NC}"
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — Hyprland Config
# ══════════════════════════════════════════════════════════════════════════════
step 1 "Hyprland Config"

_MARKER="quickshell.*Brain_Shell"

_append_conf() {
    cat << 'EOF' >> "$1"

# Brain Shell Autostarts
exec-once = awww-daemon
exec-once = hypridle -c $HOME/.local/src/Brain_Shell/src/config/hypridle.conf
exec-once = quickshell -c $HOME/.local/src/Brain_Shell/.
exec-once = systemctl --user start hyprpolkitagent
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
EOF
}

_append_lua() {
    cat << 'EOF' >> "$1"

-- Brain Shell Autostarts
hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hypridle -c " .. os.getenv("HOME") .. "/.local/src/Brain_Shell/src/config/hypridle.conf")
    hl.exec_cmd("quickshell -c " .. os.getenv("HOME") .. "/.local/src/Brain_Shell")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
EOF
}

if grep -q "$_MARKER" "$HYPRLAND_CONF" 2>/dev/null; then
    log_warn "Autostart block already present — skipping."
else
    case "$CONFIG_TYPE" in
        conf)
            _append_conf "$HYPRLAND_CONF"
            log_ok "Autostart block appended to hyprland.conf"
            ;;
        lua)
            cp "$HYPRLAND_CONF" "${HYPRLAND_CONF}.pre-brain-shell"
            _append_lua "$HYPRLAND_CONF"
            log_ok "Autostart block appended to hyprland.lua"
            ;;
    esac
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — Brain Shell Config
# ══════════════════════════════════════════════════════════════════════════════
step 2 "Brain Shell Config"

USER_DATA="$HOME/.config/Brain_Shell/src/user_data"

mkdir -p "$USER_DATA" \
         "$HOME/.config/hypr/shaders" \
         "$HOME/.config/matugen/templates" \
         "$HOME/.cache/brain-shell" \
         "$HOME/Pictures/Wallpapers"

cp -n "$REPO_DIR/src/config/hypridle.conf" "$HOME/.config/hypr/" 2>/dev/null || true
touch "$HOME/.cache/brain-shell/colors.json"
cp -n -r "$REPO_DIR/src/assets/wallpapers"/* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true

printf '{"configProvider": "%s"}\n' "$CONFIG_TYPE" > "$USER_DATA/config_Provider.json"
printf '{}\n' > "$USER_DATA/keybinds.json"

log_ok "Config and cache directories initialized."

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — NixOS Dependencies
# ══════════════════════════════════════════════════════════════════════════════
step 3 "NixOS Dependencies"

log_info "On NixOS, packages must be declared in your configuration."
echo ""
echo -e "  ${BOLD}Add the following to your configuration.nix or home.nix:${NC}"
echo -e "  ${DIM}──────────────────────────────────────────────────${NC}"
cat << 'EOF'
  environment.systemPackages = with pkgs; [
    # Qt & Core
    qt6.qtbase qt6.qtdeclarative qt6.qtmultimedia qt6.qt5compat qt6ct

    # Audio & Media
    pipewire wireplumber playerctl mpv mpc-cli

    # Utilities
    networkmanager bluez brightnessctl upower libnotify polkit
    wl-clipboard slurp xdg-user-dirs wf-recorder cava imagemagick
    wtype lm_sensors rfkill cliphist matugen

    # Hyprland Ecosystem
    hyprsunset hyprlock hypridle

    # You will need to pull Quickshell via its flake:
    # inputs.quickshell.url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
  ];
EOF
echo -e "  ${DIM}──────────────────────────────────────────────────${NC}"

if ! command -v quickshell &>/dev/null; then
    echo ""
    log_warn "Quickshell is not currently in your PATH!"
    log_warn "Brain Shell will not start until you rebuild your Nix config with Quickshell."
else
    log_ok "Quickshell detected in PATH."
fi

exit 0
