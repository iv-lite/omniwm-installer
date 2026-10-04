#!/bin/sh
# SPDX-License-Identifier: MIT
# Phase 5: optional start-at-login launchd agent and IPC guidance.

# Locate the OmniWM binary inside the app bundle.
_omniwm_binary() {
    for p in "/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME" \
             "/opt/homebrew/Caskroom/$CASK"/*/"$APP_NAME.app/Contents/MacOS/$APP_NAME" \
             "/usr/local/Caskroom/$CASK"/*/"$APP_NAME.app/Contents/MacOS/$APP_NAME"; do
        [ -x "$p" ] && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

integrate_run() {
    step "Integration"

    local start_at_login="${START_AT_LOGIN:-false}"

    # start-at-login launchd agent.
    if [ "$start_at_login" = "true" ]; then
        local bin
        bin="$(_omniwm_binary)" || die "Could not locate the $APP_NAME binary."
        if [ "$DRY_RUN" -eq 1 ]; then
            info "[dry-run] would install a LaunchAgent for start-at-login ($bin)."
        else
            run mkdir -p "$HOME/Library/LaunchAgents"
            run tee "$LAUNCH_AGENT" >/dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>$bin</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/omniwm.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/omniwm.err.log</string>
</dict>
</plist>
EOF
            run launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null \
                || run launchctl load "$LAUNCH_AGENT" 2>/dev/null \
                || warn "LaunchAgent written, but launchctl registration failed; it will load at next login."
            ok "Start-at-login agent installed."
        fi
    else
        ok "Start at login: off (enable via Settings > General > Startup, or set START_AT_LOGIN=true)."
    fi

    # IPC / omniwmctl on PATH.
    if [ "${GENERAL_IPC_ENABLED:-false}" = "true" ]; then
        info "IPC is enabled in the config. The server starts once $APP_NAME is running."
        info "Use 'omniwmctl' (Homebrew puts it on your PATH) for automation."
    else
        info "IPC is disabled. Enable it from $APP_NAME's menu bar (Enable IPC) to use omniwmctl."
    fi
}
