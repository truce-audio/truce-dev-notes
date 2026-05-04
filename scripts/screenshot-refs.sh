#!/usr/bin/env bash
#
# screenshot-refs.sh — regenerate the per-OS reference PNGs for
# every truce example crate.
#
# Run on each OS you support to refresh that OS's references:
#
#   macOS:   ./screenshot-refs.sh
#   Linux:   ./screenshot-refs.sh
#   Windows: ./screenshot-refs.sh   (under Git Bash / WSL / MSYS)
#
# Discovers `examples/truce-example-*/screenshots/` and writes
# `<prefix>_default_<os>.png` into each — matching the path the
# `gui_screenshot_<os>` test in that example reads. `<prefix>` is the
# crate name minus `truce-example-`, with `-` → `_` (e.g.
# `truce-example-gain-egui` → `gain_egui`).
#
# Usage:
#   ./screenshot-refs.sh               # all examples
#   ./screenshot-refs.sh -p gain       # only crates whose name
#                                      # contains `gain`
#   ./screenshot-refs.sh -n            # dry-run (print, don't render)
#
# Env:
#   TRUCE_REPO     Path to the truce repo (default:
#                  <script-dir>/../../truce)
#   CARGO_TRUCE    Command that invokes cargo-truce (default:
#                  `cargo run --release -p cargo-truce --` so the
#                  current workspace code is used regardless of what
#                  `cargo install cargo-truce` shipped). Override
#                  with `CARGO_TRUCE="cargo truce"` to use the
#                  installed binary instead.

set -euo pipefail

# ----------------------------------------------------------------------------
# Detect OS — must match the suffix the per-OS gui_screenshot tests
# read (`screenshots/<prefix>_default_<os>.png`).
# ----------------------------------------------------------------------------

case "$(uname -s)" in
    Darwin*)               OS="macos" ;;
    Linux*)                OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*)  OS="windows" ;;
    *)
        echo "Error: unsupported OS '$(uname -s)'. Expected Darwin / Linux / MSYS-style Windows shell." >&2
        exit 1
        ;;
esac

# ----------------------------------------------------------------------------
# Locate the truce repo
# ----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRUCE_REPO="${TRUCE_REPO:-$SCRIPT_DIR/../../truce}"

if [[ ! -d "$TRUCE_REPO" ]]; then
    echo "Error: truce repo not found at $TRUCE_REPO" >&2
    echo "Set TRUCE_REPO=/path/to/truce or place this script's parent dir next to the truce repo." >&2
    exit 1
fi

if [[ ! -d "$TRUCE_REPO/examples" ]]; then
    echo "Error: $TRUCE_REPO doesn't look like the truce repo (no examples/ dir)" >&2
    exit 1
fi

cd "$TRUCE_REPO"

# ----------------------------------------------------------------------------
# Args
# ----------------------------------------------------------------------------

DRY_RUN=0
FILTER=""

usage() {
    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=1 ;;
        -p|--plugin)
            shift
            [[ $# -gt 0 ]] || { echo "Error: -p requires a value" >&2; exit 2; }
            FILTER="$1"
            ;;
        -h|--help)    usage 0 ;;
        *)            echo "Error: unknown arg '$1' (try -h)" >&2; exit 2 ;;
    esac
    shift
done

CARGO_TRUCE="${CARGO_TRUCE:-cargo run --release -p cargo-truce --}"

# ----------------------------------------------------------------------------
# Iterate over example crates
# ----------------------------------------------------------------------------

echo "OS:        $OS"
echo "Repo:      $TRUCE_REPO"
echo "Cargo cmd: $CARGO_TRUCE"
[[ $DRY_RUN -eq 1 ]] && echo "Mode:      DRY RUN (no renders)"
[[ -n "$FILTER" ]]    && echo "Filter:    *$FILTER*"
echo

shopt -s nullglob
RENDERED=0
SKIPPED_NO_DIR=0
for dir in examples/truce-example-*/; do
    dir="${dir%/}"
    crate="$(basename "$dir")"

    # Examples without a screenshots/ dir don't have screenshot tests.
    if [[ ! -d "$dir/screenshots" ]]; then
        SKIPPED_NO_DIR=$((SKIPPED_NO_DIR + 1))
        continue
    fi

    if [[ -n "$FILTER" && "$crate" != *"$FILTER"* ]]; then
        continue
    fi

    # `truce-example-gain-egui` → `gain_egui`
    prefix="${crate#truce-example-}"
    prefix="${prefix//-/_}"
    out="$dir/screenshots/${prefix}_default_${OS}.png"

    echo "→ $crate → $out"

    if [[ $DRY_RUN -eq 1 ]]; then
        RENDERED=$((RENDERED + 1))
        continue
    fi

    # `cargo-truce`'s `screenshot` subcommand reads the workspace's
    # truce.toml relative to cwd; we already cd'd to TRUCE_REPO above.
    # `--out` is resolved relative to cwd, so the path stays inside
    # the example's dir.
    # shellcheck disable=SC2086
    $CARGO_TRUCE screenshot -p "$crate" --out "$out"

    RENDERED=$((RENDERED + 1))
done

echo
echo "Done. Rendered $RENDERED reference(s) for $OS."
if [[ $SKIPPED_NO_DIR -gt 0 ]]; then
    echo "Skipped $SKIPPED_NO_DIR example(s) with no screenshots/ dir."
fi
