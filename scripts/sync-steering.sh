#!/usr/bin/env bash
# Copy the shared steering files from this repo into a workspace's
# .kiro/steering directory so Kiro can read them locally.
#
# usage: scripts/sync-steering.sh [workspace-root]   (default: parent of this repo)
# Overwrites only the shared files listed in steering/; repo-specific files in the
# target are left alone.
#
# The target must be the multi-repo workspace root (e.g. ~/OmnisTools), NOT a
# single repo checkout: each repo keeps its own .kiro/steering/aws-environments.md
# with repo-specific lanes, and syncing into a repo would overwrite it. The
# script refuses a target that is a git checkout unless --force is given.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
force=0
if [ "${1:-}" = "--force" ]; then force=1; shift; fi
ws="${1:-$(dirname "$here")}"
dest="$ws/.kiro/steering"
[ -d "$ws" ] || { echo "error: workspace '$ws' not found" >&2; exit 2; }
if [ "$force" -eq 0 ] && git -C "$ws" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: '$ws' is inside a git checkout. Point this at the workspace root that" >&2
  echo "       contains the repos, not at a repo (it would overwrite the repo's own" >&2
  echo "       .kiro/steering files). Use --force to override." >&2
  exit 2
fi
mkdir -p "$dest"
for f in "$here"/steering/*.md; do
  cp "$f" "$dest/$(basename "$f")"
  echo "synced $(basename "$f") -> $dest"
done
