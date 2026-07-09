#!/bin/zsh
# Publish the current main tree to the public GitHub mirror as a single
# squashed snapshot commit — no development history is ever pushed.
# The .forgejo/ CI config is excluded (internal to the working repo).
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="https://github.com/botelle/nauti-husky.git"
[[ -z $(git status --porcelain) ]] || { echo "working tree dirty; commit first" >&2; exit 1; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

git archive main | tar -x -C "$STAGE"
rm -rf "$STAGE/.forgejo"

cd "$STAGE"
git init -q -b main
git config user.name "Justin Botelle"
git config user.email "justin@botelle.net"
git add -A
git commit -q -m "Public snapshot $(date +%Y-%m-%d)"
git push --force "$REPO" main
echo "Published snapshot to $REPO"
