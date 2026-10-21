#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
source_dir=$PWD
username=${SUDO_USER:-uotanklein}
[[ $username == root ]] && username=uotanklein
if (($#)); then
    [[ $# -eq 2 && $1 == --user ]] || { echo "Использование: sudo bash setup-installed.sh [--user uotanklein]" >&2; exit 1; }
    username=$2
fi
if [[ ! -e /etc/NIXOS || $EUID -ne 0 ]]; then
    echo "Запускай в установленной NixOS с sudo (или от root)." >&2; exit 1
fi
if [[ ! $username =~ ^[a-z_][a-z0-9_-]*$ || $username == root || $username == greeter ]]; then
    echo "Недопустимое имя пользователя." >&2; exit 1
fi
if [[ ! -f /etc/nixos/configuration.nix || ! -f /etc/nixos/hardware-configuration.nix ]]; then
    echo "Нет конфигурации установленной NixOS. Из ISO используй install-from-iso.sh." >&2; exit 1
fi
if [[ $(tty || true) == /dev/tty1 ]]; then
    echo "Перейди на Ctrl+Alt+F2 и войди там: запуск greetd заменит вход на tty1." >&2; exit 1
fi
if [[ -e /etc/nixos/flake.nix && ! -e /etc/nixos/.personal-desktop-managed ]]; then
    echo "В /etc/nixos уже есть flake.nix. Остановка без перезаписи чужой конфигурации." >&2; exit 1
fi
backup="/etc/nixos.before-migration-$(date +%Y%m%d-%H%M%S)"
cp -a -- /etc/nixos "$backup"
install -m 0644 nixos/flake.nix nixos/flake.lock nixos/desktop.nix /etc/nixos/
printf '{"username":"%s"}\n' "$username" > /etc/nixos/user.json
touch /etc/nixos/.personal-desktop-managed
echo "Настройка NixOS с Hyprland/Caelestia: пользователь, сеть, драйвер и рабочий стол."
export NIX_CONFIG='experimental-features = nix-command flakes'
nixos-rebuild switch --flake /etc/nixos#desktop

target_home=$(getent passwd "$username" | cut -d: -f6)
if [[ $target_home != /home/* ]]; then
    echo "Ожидался домашний каталог внутри /home, получен: $target_home" >&2; exit 1
fi
home_bundle="$target_home/nixos-migration"
mkdir -p "$home_bundle"
if [[ $(readlink -f "$home_bundle") != "$source_dir" ]]; then cp -a -- "$source_dir/." "$home_bundle/"; fi
chown -R "$username:$(id -gn "$username")" "$home_bundle"
echo "Задай или подтверди новый пароль пользователя $username."
passwd "$username"
su -l "$username" -c "bash '$home_bundle/restore-user.sh'"
echo "Готово. Перезагрузи ПК и войди через tuigreet под пользователем $username."
echo "Предыдущая конфигурация: $backup"
