#!/usr/bin/env bash
# Copy the shared steering files from this repo into a workspace's
# .kiro/steering directory so Kiro can read them locally.
#
# usage: scripts/sync-steering.sh [workspace-root]   (default: parent of this repo)
# Overwrites only the shared files listed in steering/; repo-specific files in the
# target are left alone.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ws="${1:-$(dirname "$here")}"
dest="$ws/.kiro/steering"
[ -d "$ws" ] || { echo "error: workspace '$ws' not found" >&2; exit 2; }
mkdir -p "$dest"
for f in "$here"/steering/*.md; do
  cp "$f" "$dest/$(basename "$f")"
  echo "synced $(basename "$f") -> $dest"
done
