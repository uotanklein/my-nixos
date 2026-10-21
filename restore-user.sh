#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
if [[ ! -e /etc/NIXOS || $EUID -eq 0 ]]; then
    echo "Запускай в NixOS от обычного пользователя, без sudo." >&2
    exit 1
fi
backup="$HOME/.local/state/nixos-migration-backup/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
chmod 0700 "$backup"
mkdir -p "$HOME/.config" "$HOME/.local/state" "$HOME/Pictures/Wallpapers"

for name in hypr kitty caelestia uwsm; do
    target="$HOME/.config/$name"
    if [[ -e $target || -L $target ]]; then
        mv -- "$target" "$backup/$name"
    fi
    cp -a -- "nixos/dotfiles/$name" "$target"
done

if [[ -d $HOME/.local/state/caelestia ]]; then
    cp -a -- "$HOME/.local/state/caelestia" "$backup/caelestia-state"
fi
mkdir -p "$HOME/.local/state/caelestia/wallpaper"
cp -- assets/wallpaper.webp "$HOME/Pictures/Wallpapers/caelestia.webp"
printf '%s' "$HOME/Pictures/Wallpapers/caelestia.webp" > "$HOME/.local/state/caelestia/wallpaper/path.txt"
ln -sfn "$HOME/Pictures/Wallpapers/caelestia.webp" "$HOME/.local/state/caelestia/wallpaper/current"
cp -- state/caelestia-scheme.json "$HOME/.local/state/caelestia/scheme.json"
if [[ -d $HOME/.local/state/wireplumber ]]; then
    cp -a -- "$HOME/.local/state/wireplumber" "$backup/wireplumber"
fi
mkdir -p "$HOME/.local/state/wireplumber"
cp -a -- state/wireplumber/. "$HOME/.local/state/wireplumber/"

# Restore VPN secrets ONLY in the home directory, never in /etc/nixos or the Nix store.
if [[ -f private/AmneziaVPN.conf ]]; then
    mkdir -p "$HOME/.config/AmneziaVPN.ORG"
    chmod 0700 "$HOME/.config/AmneziaVPN.ORG"
    target="$HOME/.config/AmneziaVPN.ORG/AmneziaVPN.conf"
    if [[ -e $target ]]; then cp -p -- "$target" "$backup/AmneziaVPN.conf"; fi
    install -m 0600 private/AmneziaVPN.conf "$target"
    mkdir -p "$HOME/.config/autostart"
    if [[ -e $HOME/.config/autostart/AmneziaVPN.desktop ]]; then
        cp -p "$HOME/.config/autostart/AmneziaVPN.desktop" "$backup/AmneziaVPN.desktop"
    fi
    cat > "$HOME/.config/autostart/AmneziaVPN.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=AmneziaVPN
Exec=env QT_QPA_PLATFORM=xcb AmneziaVPN --autostart
Icon=AmneziaVPN
Terminal=false
Categories=Network;
DESKTOP
    echo "Профиль AmneziaVPN восстановлен."
else
    echo "VPN-профиля в репозитории нет. Импортируй сервер в AmneziaVPN вручную."
fi
echo "Личные настройки восстановлены. Резервная копия: $backup"
