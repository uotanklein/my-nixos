#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$(readlink -f -- "$0")")"
source_dir=$PWD
target_root=/mnt
username=uotanklein
while (($#)); do
    case "$1" in
        --root) target_root=${2:?Укажи точку монтирования}; shift 2 ;;
        --user) username=${2:?Укажи пользователя}; shift 2 ;;
        *) echo "Использование: sudo bash install-from-iso.sh [--root /mnt] [--user uotanklein]" >&2; exit 1 ;;
    esac
done
if [[ ! -e /etc/NIXOS || $EUID -ne 0 ]]; then
    echo "Запускай из NixOS Graphical ISO (из терминала): sudo bash install-from-iso.sh" >&2
    exit 1
fi
if [[ ! $username =~ ^[a-z_][a-z0-9_-]*$ || $username == root || $username == greeter ]]; then
    echo "Имя пользователя: строчные латинские буквы, цифры, _ или -." >&2; exit 1
fi
if [[ ! -d /sys/firmware/efi ]]; then
    echo "Перезагрузи установочную флешку в режиме UEFI." >&2; exit 1
fi
target_root=$(readlink -f -- "$target_root")
if [[ $target_root == / || ! -d $target_root ]]; then
    echo "Недопустимый корень установки." >&2; exit 1
fi
if ! mountpoint -q -- "$target_root" || ! mountpoint -q -- "$target_root/boot"; then
    echo "Сначала смонтируй раздел Linux в $target_root и EFI-раздел в $target_root/boot." >&2
    exit 1
fi
if [[ $(findmnt -nro FSTYPE --mountpoint "$target_root/boot") != vfat ]]; then
    echo "В $target_root/boot ожидается EFI-раздел FAT32 (vfat)." >&2; exit 1
fi
if [[ $(findmnt -nro FSTYPE --mountpoint "$target_root") != btrfs && $(findmnt -nro FSTYPE --mountpoint "$target_root") != ext4 ]]; then
    echo "Этот сценарий рассчитан на корневой раздел Btrfs или ext4." >&2; exit 1
fi
for tool in nixos-generate-config nixos-install nixos-enter; do
    command -v "$tool" >/dev/null || { echo "В ISO отсутствует $tool" >&2; exit 1; }
done

config_dir="$target_root/etc/nixos"
if [[ -e $config_dir/flake.nix && ! -e $config_dir/.personal-iso-install ]]; then
    echo "В целевой системе уже есть чужой flake.nix. Остановка без перезаписи." >&2; exit 1
fi
mkdir -p "$config_dir"
nixos-generate-config --root "$target_root"
state_version=$(sed -nE 's/^[[:space:]]*system\.stateVersion[[:space:]]*=[[:space:]]*"([0-9]+\.[0-9]+)".*/\1/p' "$config_dir/configuration.nix")
if [[ ! $state_version =~ ^[0-9]{2}\.[0-9]{2}$ ]]; then
    echo "Не удалось получить system.stateVersion из сгенерированной configuration.nix." >&2; exit 1
fi
cp -p -- "$config_dir/configuration.nix" "$config_dir/configuration.nix.before-personal-$(date +%Y%m%d-%H%M%S)"
sed -e "s/@USERNAME@/$username/g" -e "s/@STATE_VERSION@/$state_version/g" \
    nixos/configuration-install.nix > "$config_dir/configuration.nix"
install -m 0644 nixos/flake.nix nixos/flake.lock nixos/desktop.nix "$config_dir/"
printf '{"username":"%s"}\n' "$username" > "$config_dir/user.json"
touch "$config_dir/.personal-iso-install"

echo "Установка NixOS, пользователя $username, NVIDIA, Hyprland и Caelestia."
echo "Разделы уже смонтированы; этот скрипт их не форматирует."
echo "В конце nixos-install попросит установить пароль root."
export NIX_CONFIG='experimental-features = nix-command flakes'
nixos-install --root "$target_root" --flake "$config_dir#desktop"

# Copy private settings into the new user's home, outside the flake/Nix store.
home_bundle="/home/$username/nixos-migration"
mkdir -p "$target_root$home_bundle"
if [[ $(readlink -f "$target_root$home_bundle") != "$source_dir" ]]; then
    cp -a -- "$source_dir/." "$target_root$home_bundle/"
fi
nixos-enter --root "$target_root" -c "/nix/var/nix/profiles/system/sw/bin/chown -R '$username:users' '$home_bundle'"
echo "Теперь задай пароль обычного пользователя $username (для входа и sudo)."
nixos-enter --root "$target_root" -c "/nix/var/nix/profiles/system/sw/bin/passwd '$username'"
nixos-enter --root "$target_root" -c \
    "/nix/var/nix/profiles/system/sw/bin/su -l '$username' -c '/nix/var/nix/profiles/system/sw/bin/bash $home_bundle/restore-user.sh'"
echo
echo "Установка завершена. Проверь сообщения выше, затем перезагрузи компьютер."
echo "После загрузки появится tuigreet: введи имя $username и его пароль."
echo "Если интернет был по Wi-Fi, после входа настрой сохранённое соединение: nmtui."
