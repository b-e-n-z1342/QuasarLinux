#!/usr/bin/env bash
pacman -Sy terminus-font --noconfirm
setfont ter-v20n
clear
echo "=================================================================================================
=                                                                                               =
=  ██████╗  ██╗   ██╗ █████╗ ███████╗ █████╗ ██████╗     ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗ =
=  ██╔═══██╗██║   ██║██╔══██╗██╔════╝██╔══██╗██╔══██╗    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝ =
=  ██║   ██║██║   ██║███████║███████╗███████║██████╔╝    ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝  =
=  ██║▄▄ ██║██║   ██║██╔══██║╚════██║██╔══██║██╔══██╗    ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗  =
=  ╚██████╔╝╚██████╔╝██║  ██║███████║██║  ██║██║  ██║    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗ =
=   ╚══▀▀═╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝ =
=                                                                                               =
=================================================================================================

set -euo pipefail
IFS=$'\n\t'

ROOT_MNT="/mnt"
BOOT_ID="Quasar"
UEFI_MODE=0

log()   { echo -e ">> $*"; }
err()   { echo -e "ERROR: $*" >&2; exit 1; }
confirm(){ read -rp "$* [y/N]: " ans && [[ $ans =~ ^[Yy]$ ]]; }

detect_uefi() {
    if [[ -d /sys/firmware/efi ]]; then
        UEFI_MODE=1
    fi
    log "UEFI mode: $UEFI_MODE"
}

select_disk() {
    lsblk -d -o NAME,SIZE,MODEL,TYPE
    read -rp "Введите имя диска (например, sda или nvme0n1): " name
    DISK="/dev/$name"
    [[ -b $DISK ]] || err "Диск $DISK не найден"
}

partition_and_mount() {
    log "Запускаю cfdisk для ручной разметки $DISK"
    echo "После выхода из cfdisk вам нужно будет указать номера разделов."
    cfdisk "$DISK"

    echo
    read -rp "Введите раздел под корень (например, sda2 или nvme0n1p2): " rpart
    ROOT_PART="/dev/$rpart"
    [[ -b $ROOT_PART ]] || err "Раздел $ROOT_PART не найден"

    if (( UEFI_MODE )); then
        read -rp "Введите EFI-раздел (например, sda1 или nvme0n1p1): " epart
        BOOT_PART="/dev/$epart"
        [[ -b $BOOT_PART ]] || err "Раздел $BOOT_PART не найден"
    else
        read -rp "Введите BOOT-раздел (например, sda1 или nvme0n1p1): " bpart
        BOOT_PART="/dev/$bpart"
        [[ -b $BOOT_PART ]] || err "Раздел $BOOT_PART не найден"
    fi

    log "Форматирую разделы..."
    if (( UEFI_MODE )); then
        mkfs.fat -F32 "$BOOT_PART"
    else
        mkfs.ext4 -F "$BOOT_PART"
    fi
    mkfs.ext4 -F "$ROOT_PART"

    log "Монтирование ROOT и BOOT..."
    mount "$ROOT_PART" "$ROOT_MNT"
    mkdir -p "$ROOT_MNT/boot${UEFI_MODE:+/efi}"
    mount "$BOOT_PART" "$ROOT_MNT/boot${UEFI_MODE:+/efi}"
}

install_base_system() {
    log "Устанавливаю базовую систему..."
    basestrap "$ROOT_MNT" \
      base base-devel linux-zen linux-zen-headers \
      openrc elogind-openrc sudo nano grub efibootmgr os-prober \
      networkmanager dhcpcd git curl wget htop mc pciutils \
      terminus-font
}

generate_fstab() {
    log "Генерация fstab..."
    mount --types proc /proc "$ROOT_MNT/proc"
    mount --rbind /sys   "$ROOT_MNT/sys"
    mount --rbind /dev   "$ROOT_MNT/dev"
    mount --rbind /run   "$ROOT_MNT/run"

    fstabgen -U "$ROOT_MNT" >> "$ROOT_MNT/etc/fstab"
    grep -q '^UUID=' "$ROOT_MNT/etc/fstab" || err "fstab пуст или некорректен"
}

configure_chroot() {
    read -rp "Введите имя нового пользователя: " USERNAME
    install -Dm644 pixmap "$ROOT_MNT/usr/share/pixmap"
    install -Dm755 INSTALL.sh "$ROOT_MNT/home/$USERNAME/INSTALL.sh"
    chown "$USERNAME:$USERNAME" "$ROOT_MNT/home/$USERNAME/INSTALL.sh"

    artix-chroot "$ROOT_MNT" /bin/bash <<EOF
set -euo pipefail

# Права и sudoers
chmod 600 /etc/{shadow,gshadow}
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Локали и время
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc
sed -i 's/^#\\(ru_RU.UTF-8 UTF-8\\)/\\1/' /etc/locale.gen
locale-gen
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

# Имя хоста и hosts
echo "quasarlinux" > /etc/hostname
cat > /etc/hosts <<H
127.0.0.1   localhost
::1         localhost
127.0.1.1   quasarlinux.localdomain quasarlinux
H

# Сеть и сервисы
rc-update add NetworkManager default
rc-update add dbus default
rc-update add udev default
rc-update add elogind default
rc-update add dhcpcd default

# Пользователь
useradd -m -G wheel,audio,video,input,storage,optical,lp,scanner -s /bin/bash "$USERNAME"
passwd "$USERNAME"
passwd root

# Брендирование системы
cat > /etc/os-release <<R
NAME="Quasar Linux"
PRETTY_NAME="Quasar Linux (Artix base)"
ID=quasar
VERSION_ID="1.0"
ANSI_COLOR="0;36"
HOME_URL="https://b-e-n-z1342.github.io"
R

# Initcpio hook
cat > /etc/initcpio/hooks/quasar-branding <<HOOK
run_hook() {
    echo "Welcome to Quasar Linux"
}
HOOK
sed -i '/^HOOKS=/ s/)/ quasar-branding)/' /etc/mkinitcpio.conf
mkinitcpio -P

# GPU-драйверы
gpu=\$(lspci -nn | grep -Ei 'VGA|3D|Display' || true)
if echo "\$gpu" | grep -qi amd; then
    pacman -S --noconfirm mesa vulkan-radeon linux-firmware-amdgpu
elif echo "\$gpu" | grep -qi intel; then
    pacman -S --noconfirm mesa vulkan-intel linux-firmware-intel
elif echo "\$gpu" | grep -qi nvidia; then
    pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils linux-firmware-nvidia
else
    pacman -S --noconfirm mesa
fi

EOF
}

install_grub() {
    log "Устанавливаю GRUB..."
    artix-chroot "$ROOT_MNT" /bin/bash <<EOF
set -euo pipefail
if (( $UEFI_MODE )); then
    grub-install --target=x86_64-efi \
                  --efi-directory=/boot/efi \
                  --bootloader-id="$BOOT_ID" \
                  --removable --recheck
    [[ -d /boot/efi/EFI/"$BOOT_ID" ]] || exit 1
else
    grub-install --target=i386-pc "$DISK" --recheck
fi

if grep -q '^GRUB_DISTRIBUTOR=' /etc/default/grub; then
    sed -i 's|^GRUB_DISTRIBUTOR=.*|GRUB_DISTRIBUTOR="Quasar Linux"|' /etc/default/grub
else
    echo 'GRUB_DISTRIBUTOR="Quasar Linux"' >> /etc/default/grub
fi

grub-mkconfig -o /boot/grub/grub.cfg
[[ -f /boot/grub/grub.cfg ]]
EOF
}

cleanup() {
    log "Размонтирование и завершение..."
    swapoff --all || true
    umount -R "$ROOT_MNT" 2>/dev/null || true
    log "Установка завершена успешно!"
}

main() {
    detect_uefi
    select_disk
    partition_and_mount
    install_base_system
    generate_fstab
    configure_chroot
    install_grub
    cleanup
}

main "$@"
