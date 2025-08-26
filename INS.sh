#!/bin/bash
pacman -Sy terminus-font --noconfirm
setfont ter-v20n
clear
echo "=================================================================================================
=                                                                                               =
=  ███████╗ ██╗   ██╗ █████╗ ███████╗ █████╗ ██████╗     ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗ =
=  ██╔═══██╗██║   ██║██╔══██╗██╔════╝██╔══██╗██╔══██╗    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝ =
=  ██║   ██║██║   ██║███████║███████╗███████║██████╔╝    ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝  =
=  ██║▄▄ ██║██║   ██║██╔══██║╚════██║██╔══██║██╔══██╗    ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗  =
=  ╚██████╔╝╚██████╔╝██║  ██║███████║██║  ██║██║  ██║    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗ =
=   ╚══▀▀═╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝ =
=                                                                                               =
=================================================================================================
"
function chroot() {
    echo "выберите разделы"
    lsblk -d -o NAME,SIZE,MODEL,TYPE
    read -p "ведите имя диска с которым будет происходить работа (например: sda): " DISK
    DISK=/dev/$DISK
    if [ ! -e "$DISK" ]; then
        echo "Ошибка: диск $DISK не существует!"
        exit 1
    fi
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT $DISK
    read -p "Введите раздел для ROOT (например, sda2): " ROOT_PART
    ROOT_PART="/dev/$ROOT_PART"

    if [ $UEFI_MODE -eq 1 ]; then
        read -p "Введите раздел для EFI (например, sda1): " BOOT_PART
        BOOT_PART="/dev/$BOOT_PART"
    else
        read -p "Введите раздел для BOOT (например, sda1): " BOOT_PART
        BOOT_PART="/dev/$BOOT_PART"
    fi
    # Проверка разделов
    [ ! -e "$ROOT_PART" ] && echo "Ошибка: $ROOT_PART не существует!" && exit 1
    [ ! -e "$BOOT_PART" ] && echo "Ошибка: $BOOT_PART не существует!" && exit 1
    mount $ROOT_PART /mnt

    if [ $UEFI_MODE -eq 1 ]; then
        mkdir -p /mnt/boot/efi
        mount $BOOT_PART /mnt/boot/efi
    else
        mkdir -p /mnt/boot
        mount $BOOT_PART /mnt/boot
    fi
    mount --types proc /proc /mnt/proc
    mount --rbind /sys /mnt/sys
    mount --rbind /dev /mnt/dev
    mount --rbind /run /mnt/run
    cp /etc/resolv.conf /mnt/etc/
    chroot /mnt
}
function install() {
    bash INSTALLING.sh
}
echo "что вы хотить сделать?"
echo "1) Chroot"
echo "2) установка "
read -p "выберите [1-2]" ins
case $ins in
    1) chroot ;;
    2) install ;;
    *) echo "неправильный выбор" 
esac
