#!/usr/bin/env bash
# Compatibility entry point; works with Graphical or Minimal ISO.
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
exec bash ./install-from-iso.sh "$@"
