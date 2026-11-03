#!/usr/bin/env bash
# Regenerates completions/ from the built binary (swift-argument-parser's generator).
# Usage: scripts/generate-completions.sh [path-to-vhash]
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bin="${1:-}"
if [[ -z "$bin" ]]; then
    (cd "$root" && swift build -c release --product vhash >&2)
    bin="$(cd "$root" && swift build -c release --show-bin-path)/vhash"
fi

mkdir -p "$root/completions"
"$bin" --generate-completion-script bash > "$root/completions/vhash.bash"
"$bin" --generate-completion-script zsh  > "$root/completions/_vhash"
"$bin" --generate-completion-script fish > "$root/completions/vhash.fish"

bash -n "$root/completions/vhash.bash"
zsh -n "$root/completions/_vhash"
echo "Wrote completions to $root/completions" >&2
