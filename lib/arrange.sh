#!/bin/sh
# SPDX-License-Identifier: MIT
# Phase 3: detect displays and build the routing/ranking blocks used by the
# config template. Sets two shell variables for configure.sh:
#   ROUTING_ARRANGEMENTS  -> "arrangements = []" (macOS mode) or a custom grid
#   MONITOR_EXTRAS        -> "" or a [monitors] ranking block
#
# Only the "horizontal" (side-by-side, single row) custom layout is implemented.
# Display names may contain spaces; they are handled line-by-line, never
# word-split.

# List connected display names (one per line) via system_profiler.
_detect_displays() {
    if command -v python3 >/dev/null 2>&1; then
        python3 - <<'PY'
import json, subprocess, sys
try:
    out = subprocess.check_output(["system_profiler", "SPDisplaysDataType", "-json"], stderr=subprocess.DEVNULL)
    data = json.loads(out)
except Exception:
    sys.exit(1)
names = []
for gpu in data.get("SPDisplaysDataType", []):
    for disp in gpu.get("spdisplays_ndrvs", []):
        n = (disp.get("_name") or "").strip()
        if n and n not in names:
            names.append(n)
print("\n".join(names))
PY
    else
        # Best-effort fallback without python: vendor/model display-name lines.
        system_profiler SPDisplaysDataType 2>/dev/null \
            | sed -n 's/^[[:space:]]*\(.*\):$/\1/p' \
            | grep -Ei 'display|lcd|monitor' \
            | awk '!seen[$0]++'
    fi
}

# Reorder a newline-delimited display list (arg 1 = file) per ARRANGE_ORDER
# (comma-separated names). Emits the ordered list on stdout.
_order_displays() {
    local src="$1" order="${ARRANGE_ORDER:-auto}"
    if [ "$order" = "auto" ] || [ -z "$order" ]; then
        cat "$src"
        return
    fi

    local tmp_ordered
    tmp_ordered="$(mktemp)" || { cat "$src"; return; }

    # Emit requested names first (in order), deduped against the detected list.
    local o n
    IFS=','
    for o in $order; do
        o="$(printf '%s' "$o" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$o" ] && continue
        while IFS= read -r n; do
            [ -n "$n" ] || continue
            if [ "$n" = "$o" ] && ! grep -qxF "$n" "$tmp_ordered"; then
                printf '%s\n' "$n" >> "$tmp_ordered"
            fi
        done < "$src"
    done
    unset IFS

    # Append any remaining detected names not already listed.
    while IFS= read -r n; do
        [ -n "$n" ] || continue
        grep -qxF "$n" "$tmp_ordered" || printf '%s\n' "$n" >> "$tmp_ordered"
    done < "$src"

    cat "$tmp_ordered"
    rm -f "$tmp_ordered"
}

arrange_run() {
    step "Detecting displays"

    # Defaults (macOS routing, no custom grid).
    ROUTING_ARRANGEMENTS="arrangements = []"
    MONITOR_EXTRAS=""

    local mode="${ARRANGE_MODE:-macOS}"
    if [ "$mode" != "custom" ]; then
        ok "Routing mode = macOS (follows system display arrangement)."
        return 0
    fi

    local names_file detected
    names_file="$(mktemp)" || die "mktemp failed"
    detected="$(_detect_displays)" || detected=""
    if [ -z "$detected" ]; then
        rm -f "$names_file"
        warn "ARRANGE_MODE=custom but no displays could be detected; falling back to macOS routing."
        return 0
    fi
    printf '%s\n' "$detected" > "$names_file"

    local count
    count="$(grep -c . "$names_file")"
    if [ "$count" -le 1 ]; then
        rm -f "$names_file"
        ok "Single display detected; no custom grid needed."
        return 0
    fi

    local ordered_file
    ordered_file="$(mktemp)" || { rm -f "$names_file"; die "mktemp failed"; }
    _order_displays "$names_file" > "$ordered_file"

    ok "Custom horizontal arrangement for $count displays:"
    local idx=0 n
    while IFS= read -r n; do
        [ -n "$n" ] || continue
        info "  column $idx (row 0): $n"
        idx=$((idx + 1))
    done < "$ordered_file"

    local arr_id
    arr_id="$(command -v uuidgen >/dev/null 2>&1 && uuidgen | tr 'a-z' 'A-Z' || echo "OMNIWM-$(date +%s)-$$")"

    # Routing grid: one row, columns left -> right.
    local block="
[[routing.arrangements]]
id = \"$arr_id\"
"
    idx=0
    while IFS= read -r n; do
        [ -n "$n" ] || continue
        block="$block
[[routing.arrangements.monitors]]
gridColumn = $idx
gridRow = 0
monitorName = \"$n\"
"
        idx=$((idx + 1))
    done < "$ordered_file"
    ROUTING_ARRANGEMENTS="$block"

    # Monitor ranking: same left -> right order defines Main/Secondary/Tertiary.
    local ranking="
[monitors]
"
    while IFS= read -r n; do
        [ -n "$n" ] || continue
        ranking="$ranking
[[monitors.ranking]]
name = \"$n\"
"
    done < "$ordered_file"
    MONITOR_EXTRAS="$ranking"

    rm -f "$names_file" "$ordered_file"
}
