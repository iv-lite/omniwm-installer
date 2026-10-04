#!/bin/sh
# SPDX-License-Identifier: MIT
# Uninstall: quit the app, remove the launch agent, uninstall the cask, and
# optionally purge config, state, and TCC permissions.

# Flags consumed from the environment (set by the `uninstall` entry point):
#   PURGE=1             remove config + state + app-support dirs
#   KEEP_CONFIG=1       force-keep ~/.config/omniwm even with PURGE
#   PURGE_PERMISSIONS=1 reset TCC grants via tccutil
#   NON_INTERACTIVE / DRY_RUN from common.sh

uninstall_run() {
    step "Uninstalling $APP_NAME"

    # 1. Quit the running app.
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
        info "Quitting $APP_NAME..."
        run osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null \
            || run pkill -x "$APP_NAME" 2>/dev/null
    else
        ok "$APP_NAME is not running."
    fi

    # 2. Remove the launch agent (installed by integrate.sh).
    if [ -f "$LAUNCH_AGENT" ]; then
        info "Removing launch agent..."
        run launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null \
            || run launchctl unload "$LAUNCH_AGENT" 2>/dev/null
        run rm -f "$LAUNCH_AGENT"
        ok "Launch agent removed."
    else
        ok "No launch agent present."
    fi

    # 3. Uninstall the cask.
    if brew list --cask "$CASK" >/dev/null 2>&1; then
        info "Uninstalling cask..."
        run brew uninstall --cask "$CASK" || warn "brew uninstall reported an error."
    else
        ok "Cask '$CASK' is not installed via Homebrew."
        if [ -d "/Applications/$APP_NAME.app" ]; then
            warn "Found /Applications/$APP_NAME.app (not Homebrew-managed). Remove it manually if desired."
        fi
    fi

    # 4. Purge config / state / app-support.
    local purge="${PURGE:-0}"
    if [ "$purge" = "1" ] && [ "${KEEP_CONFIG:-0}" = "0" ]; then
        info "Removing configuration and state..."
        for dir in "$CONFIG_DIR" "$STATE_DIR" "$APP_SUPPORT_DIR"; do
            if [ -e "$dir" ]; then
                run rm -rf "$dir" && ok "Removed $dir"
            fi
        done
    else
        info "Keeping configuration/state. Use --purge to remove:"
        info "  $CONFIG_DIR"
        info "  $STATE_DIR"
        info "  $APP_SUPPORT_DIR"
    fi

    # 5. Reset TCC permissions.
    if [ "${PURGE_PERMISSIONS:-0}" = "1" ]; then
        info "Resetting macOS privacy permissions (tccutil)..."
        for svc in Accessibility ListenEvent ScreenCapture; do
            run tccutil reset "$svc" "$BUNDLE_ID" 2>/dev/null \
                && ok "Reset $svc for $BUNDLE_ID" \
                || warn "Could not reset $svc (may require Full Disk Access)."
        done
    fi

    ok "Uninstall complete."
    warn "'Displays have separate Spaces' was left untouched (it is a system preference)."
}
