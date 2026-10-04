#!/bin/sh
# SPDX-License-Identifier: MIT
# Phase 1: verify the machine can run OmniWM and that Homebrew is available.

checks_run() {
    step "Checking prerequisites"

    # 1. Architecture — Apple Silicon only.
    local arch
    arch="$(uname -m)"
    case "$arch" in
        arm64|aarch64) ok "Apple Silicon ($arch)" ;;
        *)
            err "OmniWM requires Apple Silicon; this machine is $arch."
            die "Unsupported architecture."
            ;;
    esac

    # 2. macOS version — 26 (Tahoe) or later.
    local ver
    ver="$(sw_vers -productVersion 2>/dev/null)"
    local major
    major="${ver%%.*}"
    if [ -z "$ver" ]; then
        warn "Could not determine macOS version (sw_vers missing)."
    elif [ "$major" -ge 26 ] 2>/dev/null; then
        ok "macOS $ver"
    else
        err "OmniWM requires macOS 26 (Tahoe) or later; you have $ver."
        die "Unsupported macOS version."
    fi

    # 3. Homebrew — required for the cask install path.
    if command -v brew >/dev/null 2>&1; then
        ok "Homebrew found at $(command -v brew)"
    else
        err "Homebrew is not installed."
        die "Install Homebrew first: https://brew.sh  (this installer uses the official cask)."
    fi

    # 4. "Displays have separate Spaces" — report, do not silently change it.
    #     It forces a logout to take effect and is the macOS default (ON).
    local spans
    spans="$(defaults read com.apple.spaces spans-displays 2>/dev/null || true)"
    if [ -z "$spans" ]; then
        warn "Could not read 'Displays have separate Spaces' (com.apple.spaces spans-displays)."
        warn "Verify it is ON under System Settings > Desktop & Dock > Mission Control."
    elif [ "$spans" = "0" ]; then
        ok "Displays have separate Spaces: ON"
    else
        warn "Displays have separate Spaces appears to be OFF (spans-displays = $spans)."
        warn "OmniWM pauses window management until it is enabled."
        info "Enable it and log out/in before relying on tiling."
    fi

    ok "Prerequisite checks complete."
}
