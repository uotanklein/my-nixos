#!/usr/bin/env bash
# DESTRUCTIVE, opt-in helper. It is never invoked by either installation script.
set -euo pipefail
if [[ ! -e /etc/NIXOS || $EUID -ne 0 ]]; then
    echo "Только из NixOS Graphical ISO с sudo. Этот скрипт удаляет разделы выбранного диска." >&2; exit 1
fi
if [[ $# -ne 1 ]]; then
    echo "Использование: sudo bash prepare-disk.sh /dev/disk/by-id/ИМЯ-ДИСКА" >&2; exit 1
fi
disk=$(readlink -f -- "$1")
if [[ ! -b $disk || $(lsblk -dnro TYPE "$disk") != disk ]]; then
    echo "Ожидался целый физический диск, а не раздел." >&2; exit 1
fi
if [[ -n $(lsblk -nrpo MOUNTPOINT "$disk" | tr -d '[:space:]') ]]; then
    echo "У выбранного диска есть смонтированные разделы или активный swap. Остановка." >&2
    lsblk -o NAME,SIZE,MODEL,MOUNTPOINTS "$disk" >&2; exit 1
fi
if mountpoint -q /mnt; then
    echo "/mnt уже занят. Этот помощник рассчитан на ещё не подготовленные разделы." >&2; exit 1
fi
if [[ ! -d /sys/firmware/efi ]]; then echo "Загрузи ISO в UEFI." >&2; exit 1; fi
for tool in parted mkfs.fat mkfs.btrfs btrfs udevadm; do
    command -v "$tool" >/dev/null || { echo "Отсутствует $tool; см. GRAPHICAL-INSTALL.txt." >&2; exit 1; }
done
if (( $(blockdev --getsize64 "$disk") < 68719476736 )); then
    echo "Для этого шаблона требуется диск не меньше 64 ГиБ." >&2; exit 1
fi
serial=$(lsblk -dnro SERIAL "$disk" | xargs)
[[ -n $serial ]] || serial=$(basename "$disk")
lsblk -o NAME,SIZE,MODEL,SERIAL,MOUNTPOINTS "$disk"
echo "ВСЕ РАЗДЕЛЫ И ДАННЫЕ НА $disk БУДУТ УДАЛЕНЫ."
echo "Будут созданы GPT, EFI 4 ГиБ и Btrfs с @ и @home."
confirmation="ERASE-$serial"
read -r -p "Для подтверждения введи $confirmation: " answer </dev/tty
if [[ $answer != "$confirmation" ]]; then echo "Отменено."; exit 1; fi
if [[ $(lsblk -dnro SERIAL "$disk" | xargs) != "$serial" && $(basename "$disk") != "$serial" ]]; then
    echo "Идентификатор диска изменился. Остановка." >&2; exit 1
fi
if [[ -n $(lsblk -nrpo MOUNTPOINT "$disk" | tr -d '[:space:]') ]]; then
    echo "Диск оказался смонтирован во время ожидания. Остановка." >&2; exit 1
fi

parted -s "$disk" mklabel gpt
parted -s "$disk" mkpart NIXOS-EFI fat32 1MiB 4097MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart NIXOS-ROOT btrfs 4097MiB 100%
udevadm settle
efi=$(lsblk -nrpo NAME,PARTLABEL "$disk" | awk '$2=="NIXOS-EFI" {print $1}')
root=$(lsblk -nrpo NAME,PARTLABEL "$disk" | awk '$2=="NIXOS-ROOT" {print $1}')
[[ -b $efi && -b $root ]] || { echo "Не найдены созданные разделы." >&2; exit 1; }
mkfs.fat -F 32 -n NIXOS-EFI "$efi"
mkfs.btrfs -f -L NIXOS "$root"
mkdir -p /mnt
mount "$root" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt
mount -o subvol=@,compress=zstd,noatime "$root" /mnt
mkdir -p /mnt/home /mnt/boot
mount -o subvol=@home,compress=zstd,noatime "$root" /mnt/home
mount "$efi" /mnt/boot
echo "Разделы подготовлены и смонтированы. Далее: sudo bash install-from-iso.sh"
