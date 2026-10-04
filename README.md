# omniwm-installer

A configurable installer for [OmniWM](https://github.com/OmniNull/OmniWM) — the
Niri-style **scrolling tiling** window manager for Apple Silicon Macs (macOS 26+).

It installs OmniWM via the official Homebrew cask and writes a tuned
`settings.toml` that makes the scrolling-tiling experience work the way Niri
users expect: orientation-aware scrolling columns, snapping scroll gestures,
tighter control over gaps/borders, and (optionally) a custom horizontal
multi-monitor routing grid.

- Zero dependencies beyond Homebrew itself (POSIX `sh` + standard macOS tools).
- Declarative config (`config/niri.conf`) with an interactive fallback.
- Idempotent — safe to re-run to upgrade or re-configure.
- Ships a matching `uninstall` script.

## Requirements

- Apple Silicon Mac
- macOS 26 (Tahoe) or later
- [Homebrew](https://brew.sh)

## Install

```sh
./install
```

Options:

```sh
./install --config ./my-values.conf   # merge KEY=value overrides on top of the preset
./install --non-interactive           # never prompt
./install --force                     # overwrite an existing settings.toml (backed up first)
./install --skip-install              # config-only (OmniWM already installed)
./install --no-start-at-login         # don't add the launchd agent
./install --dry-run                   # print what would happen, change nothing
```

What it does, in order:

1. **Checks** — Apple Silicon, macOS 26+, Homebrew, and reports the
   "Displays have separate Spaces" state.
2. **Installs** — `brew install --cask omniwm` (or offers an upgrade).
3. **Detects displays** — see [Multi-monitor](#multi-monitor) below.
4. **Writes config** — renders `~/.config/omniwm/settings.toml` from
   `templates/settings.toml`, substituting your values.
5. **Integrates** — optional start-at-login LaunchAgent; IPC notes.
6. **Guides** — the permission steps macOS won't let a script automate
   (Accessibility, Input Monitoring, optional Screen Recording).

> **First launch is still manual.** OmniWM requires Accessibility and Input
> Monitoring, which are TCC-protected and must be granted by clicking in System
> Settings. The installer prints the exact panes to open. After granting, launch
> OmniWM and click **Start**.

## Uninstall

```sh
./uninstall --purge                # also remove config, state, and app-support
./uninstall --purge --keep-config  # purge but keep ~/.config/omniwm
./uninstall --purge-permissions    # reset Accessibility/InputMonitoring/ScreenRecording grants
./uninstall --dry-run
```

## Configuration

Edit `config/niri.conf` (KEY=value), then re-apply with
`./install --skip-install --force`. Every value maps to a `{{TOKEN}}` in the
template; unknown keys are ignored, so a typo falls back to the preset value.

Notable defaults (the "niri scrolling tiling" preset):

| Area | Key | Default |
|------|-----|---------|
| layout | `GENERAL_DEFAULT_LAYOUT_TYPE` | `niri` |
| niri | `NIRI_VISIBLE_CONTAINER_COUNT` | `2` |
| niri | `NIRI_CENTER_FOCUSED_COLUMN` | `onOverflow` |
| niri | `NIRI_ALWAYS_CENTER_SINGLE_COLUMN` | `true` |
| niri | `NIRI_SINGLE_WINDOW_FIT` | `fill` |
| niri | `NIRI_RESIZE_STEP_PERCENT` | `5` |
| gaps | `GAPS_SIZE` | `16.0` |
| border | `BORDER_WIDTH` | `5.0` |
| gestures | `GESTURES_TRACKPAD_SCROLL_STYLE` | `snap` |
| gestures | `GESTURES_FINGER_COUNT` | `3` |
| gestures | `GESTURES_SCROLL_MODIFIER_KEY` | `optionShift` |

### Border color

The focused-window border uses `#2b303cd4` (a slate with alpha), stored as
`BORDER_COLOR_*` floats. There is no **inactive** border in OmniWM today — the
`#2b303cd6` value is left commented in `config/niri.conf` for when the schema
grows an inactive-border key.

### Multi-monitor (horizontal arrangement)

Set `ARRANGE_MODE=custom` and the installer detects connected displays and
writes a side-by-side routing grid (`[[routing.arrangements]]`) plus a
`[monitors]` ranking, left → right:

```toml
[routing]
mode = "custom"

[[routing.arrangements]]
id = "…"
[[routing.arrangements.monitors]]
gridColumn = 0
gridRow = 0
monitorName = "DELL U2720Q"
```

With `ARRANGE_MODE=macOS` (the default) OmniWM simply follows the system
display arrangement. `MOUSE_WARP_ENABLED` and `FOCUS_CROSSES_MONITOR_AT_EDGE`
control the related edge behavior.

> Display names come from `system_profiler`; UUIDs are omitted, so the grid uses
> OmniWM's documented name fallback. If two displays share a name, reorder them
> via the `ARRANGE_ORDER` comment in `config/niri.conf` or finish setup in
> OmniWM's **Settings → Monitors**.

## How the template works

OmniWM's `settings.toml` uses a **strict** `schemaVersion = 4` schema: a missing
required key — or a missing/duplicate/unknown hotkey action — rejects the whole
file. This installer therefore ships a **complete** canonical template
(`templates/settings.toml`) containing all required keys, all **190** hotkey
actions, the nine default workspaces, and the thirteen built-in app rules. Only
the values you care about are tokenized; everything else ships as the upstream
defaults.

### Regenerating the template after an OmniWM schema bump

When OmniWM changes its schema, regenerate the template from a freshly installed
build rather than hand-editing it:

1. `brew upgrade omniwm`, launch it, then from the menu bar use
   **Reveal Settings File** to open its emitted canonical `settings.toml`.
2. Diff that file against `templates/settings.toml`, porting over any new or
   renamed keys/hotkeys.
3. Re-verify with `./install --dry-run --force` and check OmniWM's Diagnostics
   on first launch.

The installer targets the current `main` schema (v4). If the installed cask
release lags `main`, newer optional keys are simply ignored (unknown keys are
preserved, not rejected); required-key changes across a major schema bump should
be handled by regenerating the template.

## Files

```
install                     # entry point
uninstall                   # entry point
lib/checks.sh               # arch / macOS / brew / separate-Spaces
lib/install.sh              # brew install --cask omniwm
lib/arrange.sh              # display detection + routing grid
lib/configure.sh            # render settings.toml from the template
lib/integrate.sh            # start-at-login LaunchAgent + IPC
lib/uninstall.sh            # quit → agent → brew uninstall → purge
lib/guide.sh                # permissions walkthrough
config/niri.conf            # the preset (edit this)
templates/settings.toml     # canonical v4 config with {{TOKENS}}
```

## License

MIT (the installer only). OmniWM itself is GPL-2.0-only.
