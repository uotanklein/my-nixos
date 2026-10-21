#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
if [[ ! -e /etc/NIXOS ]]; then
    echo "Запускай только ПОСЛЕ установки NixOS. Из Graphical ISO используй install-from-iso.sh." >&2
    exit 1
fi
if [[ $EUID -eq 0 ]]; then
    exec bash ./setup-installed.sh "$@"
else
    exec sudo bash ./setup-installed.sh "$@"
fi
