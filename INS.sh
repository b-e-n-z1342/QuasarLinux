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
UEFI_MODE=0
[ -d /sys/firmware/efi ] && UEFI_MODE=1
function chroot_recovery() {
    echo "выберите разделы"
    lsblk -d -o NAME,SIZE,MODEL,TYPE
    read -p "введите имя диска с которым будет происходить работа (например: sda): " DISK
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
        mount $BOOT_PART /mnt/boot/efi
    else
        mount $BOOT_PART /mnt/boot
    fi
    mount --types proc /proc /mnt/proc
    mount --rbind /sys /mnt/sys
    mount --rbind /dev /mnt/dev
    mount --rbind /run /mnt/run
    cp /etc/resolv.conf /mnt/etc/
    command chroot /mnt /bin/bash
}
function install_system() {
    bash INSTALLING.sh
}
echo "что вы хотить сделать?"
echo "1) Chroot"
echo "2) установка "
read -p "выберите [1-2]" ins
case $ins in
    1) chroot_recovery ;;
    2) install_system ;;
    *) echo "неправильный выбор" ;;
esac
