#!/bin/sh
# SPDX-License-Identifier: MIT
# Phase 2: install OmniWM via the official Homebrew cask (idempotent).

install_run() {
    step "Installing $APP_NAME (Homebrew cask)"

    if [ "$DRY_RUN" -eq 1 ]; then
        if brew list --cask "$CASK" >/dev/null 2>&1; then
            info "[dry-run] $APP_NAME is already installed; would run 'brew upgrade $CASK'."
        else
            info "[dry-run] would run 'brew install --cask $CASK'."
        fi
        return 0
    fi

    if brew list --cask "$CASK" >/dev/null 2>&1; then
        ok "$APP_NAME is already installed."
        local installed current
        installed="$(brew list --cask --versions "$CASK" | awk '{print $NF}')"
        current="$(brew info --cask "$CASK" --json=v2 2>/dev/null | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | head -n1)"
        if [ -n "$current" ] && [ "$installed" != "$current" ]; then
            info "Upgrade available ($installed -> $current)."
            if confirm "Upgrade $APP_NAME now?" y; then
                info "Quit $APP_NAME first if it is running, then run:"
                info "  brew upgrade $CASK"
                run brew upgrade "$CASK" || die "brew upgrade failed."
            fi
        fi
        return 0
    fi

    info "Running: brew install --cask $CASK"
    run brew install --cask "$CASK" || die "brew install --cask $CASK failed."

    if [ -d "/Applications/$APP_NAME.app" ] || brew list --cask "$CASK" >/dev/null 2>&1; then
        ok "$APP_NAME installed."
    else
        warn "$APP_NAME was installed, but /Applications/$APP_NAME.app was not found."
    fi
}
