#!/usr/bin/env bash
# Screenshot every example plugin on the current OS and write the PNGs into
# each example crate's own `screenshots/` dir, suffixed with the OS name so
# baselines from all three platforms can coexist.
#
# Naming: examples/<crate>/screenshots/<short>_default_<os>.png
#   crate = `truce-example-<short>`  (e.g. truce-example-gain → gain)
#   os    = windows | macos | linux
# Hyphens in `<short>` are converted to underscores so the filename
# matches the path passed to `truce_test::screenshot!()` in source —
# that macro resolves its arg literally, not via crate-name munging.
#
# Lives in `truce-dev-notes/scripts/` next to the truce repo; cd's into
# the sibling `truce/` workspace so screenshot output paths resolve there.

set -euo pipefail

cd "$(dirname "$0")/../../truce"

case "$(uname -s)" in
    Darwin)                                            os=macos;   cargo=cargo ;;
    Linux)
        # WSL: even though uname says Linux, builds target Windows
        # via cargo.exe (CLAUDE.md convention). Detect via
        # WSL_DISTRO_NAME or the kernel's "microsoft" tag.
        if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
            os=windows; cargo=cargo.exe
        else
            os=linux;   cargo=cargo
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*) os=windows; cargo=cargo.exe ;;
    *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

echo "OS: $os  (using $cargo)"
echo

failed=()
for crate_dir in examples/truce-example-*/; do
    crate=$(basename "$crate_dir")
    short=${crate#truce-example-}
    short=${short//-/_}
    out_dir="$crate_dir/screenshots"
    out="$out_dir/${short}_default_${os}.png"

    mkdir -p "$out_dir"
    echo "=== $crate → $out ==="
    if "$cargo" truce screenshot -p "$crate" --out "$out"; then
        echo
    else
        failed+=("$crate")
        echo "FAILED: $crate"
        echo
    fi
done

if [ ${#failed[@]} -ne 0 ]; then
    echo "Failed: ${failed[*]}" >&2
    exit 1
fi

echo "All screenshots written."
