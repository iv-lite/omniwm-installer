#!/bin/sh
# SPDX-License-Identifier: MIT
# Phase 6: guide the user through the parts macOS will not let us automate.

guide_run() {
    step "Remaining manual steps"

    echo
    echo "1. 'Displays have separate Spaces' — System Settings > Desktop & Dock > Mission Control."
    echo "   Ensure it is ON (the macOS default). It requires a logout/login to take effect."
    echo
    echo "2. Permissions (required) — grant when $APP_NAME prompts, or open the panes below:"
    echo "   - Accessibility:     ${c_bold}open \"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\"${c_reset}"
    echo "   - Input Monitoring:  ${c_bold}open \"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent\"${c_reset}"
    echo "   - Screen Recording (optional):"
    echo "     ${c_bold}open \"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture\"${c_reset}"
    echo
    echo "3. Launch $APP_NAME from /Applications and click Start (or Continue Without Screen Recording)."
    echo
    if confirm "Open the Accessibility settings pane now?" n; then
        run open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    fi

    ok "Done. Enjoy your niri-style scrolling tiling."
}
