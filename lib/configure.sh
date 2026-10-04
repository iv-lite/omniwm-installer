#!/bin/sh
# SPDX-License-Identifier: MIT
# Phase 4: render templates/settings.toml with the loaded configuration and
# write it to ~/.config/omniwm/settings.toml.
#
# Expects, from earlier phases (same shell):
#   - exported config keys (GENERAL_*, NIRI_*, GAPS_*, BORDER_*, GESTURES_*, ...)
#   - ROUTING_ARRANGEMENTS and MONITOR_EXTRAS shell variables (from arrange.sh)

configure_run() {
    step "Writing OmniWM configuration"

    local tmp tmp_routing tmp_monitors
    tmp="$(mktemp -t omniwm-settings).toml" || die "mktemp failed"
    tmp_routing="$(mktemp)" || { rm -f "$tmp"; die "mktemp failed"; }
    tmp_monitors="$(mktemp)" || { rm -f "$tmp" "$tmp_routing"; die "mktemp failed"; }

    # 1. Substitute flat {{TOKEN}} values from the exported config environment.
    #    The two block tokens are left literal for the next pass.
    awk '
        {
            line = $0
            out = ""
            while (match(line, /\{\{[A-Z0-9_]+\}\}/)) {
                token = substr(line, RSTART + 2, RLENGTH - 4)
                out = out substr(line, 1, RSTART - 1)
                if (token == "ROUTING_ARRANGEMENTS" || token == "MONITOR_EXTRAS") {
                    out = out substr(line, RSTART, RLENGTH)
                } else {
                    out = out ENVIRON[token]
                }
                line = substr(line, RSTART + RLENGTH)
            }
            print out line
        }
    ' "$TEMPLATE" > "$tmp"

    # 2. Inject the multi-line routing/ranking blocks from temp files.
    printf '%s' "${ROUTING_ARRANGEMENTS:-arrangements = []}" > "$tmp_routing"
    printf '%s' "${MONITOR_EXTRAS:-}" > "$tmp_monitors"
    awk -v rf="$tmp_routing" -v mf="$tmp_monitors" '
        $0 == "{{ROUTING_ARRANGEMENTS}}" { while ((getline l < rf) > 0) print l; close(rf); next }
        $0 == "{{MONITOR_EXTRAS}}"       { while ((getline l < mf) > 0) print l; close(mf); next }
        { print }
    ' "$tmp" > "$tmp.tmp"
    mv "$tmp.tmp" "$tmp"
    rm -f "$tmp_routing" "$tmp_monitors"

    # 3. Validate the rendered file.
    if grep -Eq '\{\{[A-Z0-9_]+\}\}' "$tmp"; then
        err "Unresolved template tokens remain — the config would be invalid:"
        grep -nE '\{\{[A-Z0-9_]+\}\}' "$tmp" | sed 's/^/    /' >&2
        rm -f "$tmp"
        die "Aborting. Check config/niri.conf and your --config file."
    fi
    if ! grep -q '^schemaVersion = 4' "$tmp"; then
        rm -f "$tmp"
        die "Rendered config is missing 'schemaVersion = 4'."
    fi
    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        die "Rendered config is empty."
    fi

    # 4. Install, backing up an existing file only with --force.
    local dest="$CONFIG_FILE"
    if [ -e "$dest" ]; then
        if [ "$FORCE" -eq 1 ]; then
            local bak="$dest.bak-$(date +%Y%m%d-%H%M%S)"
            run cp "$dest" "$bak" || { rm -f "$tmp"; die "Backup failed."; }
            ok "Backed up existing config -> $(basename "$bak")"
        else
            rm -f "$tmp"
            warn "Configuration already exists: $dest"
            warn "Re-run with --force to overwrite (the existing file is backed up first)."
            return 0
        fi
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        info "[dry-run] would write: $dest"
        rm -f "$tmp"
        return 0
    fi

    run mkdir -p "$CONFIG_DIR" || { rm -f "$tmp"; die "mkdir -p $CONFIG_DIR failed."; }
    run cp "$tmp" "$dest" || { rm -f "$tmp"; die "Failed to write $dest."; }
    rm -f "$tmp"
    ok "Wrote $dest"
    info "OmniWM live-reloads this file on save; no restart needed."
}
