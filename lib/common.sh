#!/bin/sh
# SPDX-License-Identifier: MIT
# Shared helpers for the omniwm-installer. Source with `. "$(dirname "$0")/common.sh"`.

# --- constants ---------------------------------------------------------------
APP_NAME="OmniWM"
BUNDLE_ID="com.barut.OmniWM"
CASK="omniwm"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omniwm"
CONFIG_FILE="$CONFIG_DIR/settings.toml"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omniwm"
APP_SUPPORT_DIR="$HOME/Library/Application Support/$BUNDLE_ID"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

# Repository root. Entry points set ROOT_DIR before sourcing; fall back to
# resolving one level up from lib/ otherwise.
: "${ROOT_DIR:=$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$ROOT_DIR/lib"
TEMPLATE="$ROOT_DIR/templates/settings.toml"
DEFAULT_CONFIG="$ROOT_DIR/config/niri.conf"

# --- terminal output ----------------------------------------------------------
# Colors are emitted only when stdout is a TTY.
if [ -t 1 ]; then
    c_reset='\033[0m'; c_bold='\033[1m'; c_dim='\033[2m'
    c_red='\033[31m'; c_green='\033[32m'; c_yellow='\033[33m'; c_cyan='\033[36m'
else
    c_reset=''; c_bold=''; c_dim=''; c_red=''; c_green=''; c_yellow=''; c_cyan=''
fi

info()  { printf "${c_cyan}==>${c_reset} %s\n" "$*"; }
ok()    { printf "${c_green}  ✓${c_reset} %s\n" "$*"; }
warn()  { printf "${c_yellow}  !${c_reset} %s\n" "$*" >&2; }
err()   { printf "${c_red}  ✗${c_reset} %s\n" "$*" >&2; }

die() {
    err "$*"
    exit 1
}

# --- state --------------------------------------------------------------------
# Global flags set by the entry point before phases run.
: "${NON_INTERACTIVE:=0}"
: "${DRY_RUN:=0}"
: "${FORCE:=0}"

step() {
    printf "${c_bold}\n—— %s ——${c_reset}\n" "$*"
}

# Print the command that would run, or run it, depending on DRY_RUN.
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf "${c_dim}[dry-run]${c_reset} %s\n" "$*"
    else
        "$@"
    fi
}

# Ask a yes/no question. In non-interactive mode returns the default.
confirm() {
    local prompt="$1" default="${2:-n}"
    [ "$NON_INTERACTIVE" -eq 1 ] && { [ "$default" = "y" ]; return; }
    local ans
    printf "${c_bold}%s${c_reset} [y/N] " "$prompt"
    read -r ans </dev/tty || ans=""
    case "$ans" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# --- config loading -----------------------------------------------------------
# Load KEY=value pairs from a config file into the environment. Comments and
# blank lines are ignored; surrounding quotes on values are stripped. Values
# that look like numbers/bools are left as-is (template substitution is textual).
load_config() {
    local file="$1"
    [ -f "$file" ] || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|'#'*|' '*|$'\t'*) continue ;;
        esac
        case "$line" in
            *=*) ;;
            *) continue ;;
        esac
        key="${line%%=*}"
        val="${line#*=}"
        # strip surrounding single or double quotes
        case "$val" in
            \"*\"|\'*\') val="${val#?}"; val="${val%?}" ;;
        esac
        # strip inline trailing comment (value may contain '#' only if quoted)
        export "$key=$val"
    done < "$file"
}
