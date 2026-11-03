#!/usr/bin/env bash
# Tags a release, pushes the tag, and prints the sha256 for Formula/vhash.rb.
# Usage: scripts/release.sh 0.1.0
set -euo pipefail

version="${1:?usage: release.sh <version>  (e.g. 0.1.0)}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

grep -q "\"$version\"" Sources/VHashCore/VHashInfo.swift \
    || { echo "VHashInfo.version is not $version; update it (and CHANGELOG.md) first." >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "Working tree is dirty; commit first." >&2; exit 1; }

swift test
git tag -a "v$version" -m "vhash $version"
git push origin "v$version"

repo_url="$(git remote get-url origin | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##')"
tarball="$repo_url/archive/refs/tags/v$version.tar.gz"
sha="$(curl -fsSL "$tarball" | shasum -a 256 | cut -d' ' -f1)"

cat <<MSG

Tarball: $tarball
sha256:  $sha

Update Formula/vhash.rb (url + sha256), copy it to your tap repository
(homebrew-tap/Formula/vhash.rb), then commit and push the tap.
MSG
