#!/bin/bash


echo "
██████╗ ██╗   ██╗ █████╗ ███████╗ █████╗ ██████╗ 
██╔═══██╗██║   ██║██╔══██╗██╔════╝██╔══██╗██╔══██╗
██║   ██║██║   ██║███████║███████╗███████║██████╔╝
██║▄▄ ██║██║   ██║██╔══██║╚════██║██╔══██║██╔══██╗
╚██████╔╝╚██████╔╝██║  ██║███████║██║  ██║██║  ██║
 ╚══▀▀═╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
"
echo "Установка Quasar Linux"

# Проверка на root
if [ "$(id -u)" != "0" ]; then
    echo "Этот скрипт должен запускаться от root!"
    exit 1
fi

# Выбор диска
echo "Доступные диски:"
lsblk -d -o NAME,SIZE,MODEL
read -p "Введите имя диска (например, sda/sdb): " DISK
DISK="/dev/$DISK"

# Проверка существования диска
if [ ! -e "$DISK" ]; then
    echo "Ошибка: диск $DISK не существует!"
    exit 1
fi

# Выбор схемы разметки
PS3='Выберите схему разметки: '
options=("MBR (BIOS)" "GPT (UEFI)" "Отмена")
$select opt in "${options[@]}"
do
    case $opt in
        "MBR (BIOS)")
            SCHEME="mbr"
            break
            ;;
        "GPT (UEFI)")
            SCHEME="gpt"
            break
            ;;
        "Отмена")
            echo "Отмена операции"
            exit 0
            ;;
        *) echo "Неправильный вариант";;
    esac
    done

# Подтверждение
read -p "ВСЕ ДАННЫЕ НА $DISK БУДУТ УДАЛЕНЫ! Продолжить? (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Отмена"
    exit 0
fi

 #Очистка диска
wipefs -a -f $DISK
partprobe $DISK

# Разметка диска
case $SCHEME in
    "mbr")
        # Создание разделов MBR
       parted -s $DISK mklabel msdos
       parted -s $DISK mkpart primary 1MiB 513MiB
        parted -s $DISK set 1 boot on
        parted -s $DISK mkpart primary 513MiB 100%
        ;;
    "gpt")
        # Создание разделов GPT
        parted -s $DISK mklabel gpt
        parted -s $DISK mkpart "EFI" fat32 1MiB 513MiB
        parted -s $DISK set 1 esp on
        parted -s $DISK mkpart "ROOT" ext4 513MiB 100%
        ;;
esac

# Форматирование разделов
case $SCHEME in
    "mbr")
        mkfs.ext4 ${DISK}1
        mkfs.ext4 ${DISK}2
        ;;
    "gpt")
        mkfs.fat -F32 ${DISK}1
        mkfs.ext4 ${DISK}2
        ;;
esac

# Монтирование
mount ${DISK}2 /mnt
case $SCHEME in
    "mbr")
        mkdir -p /mnt/boot
        mount ${DISK}1 /mnt/boot
        ;;
    "gpt")
        mkdir -p /mnt/boot/efi
        mount ${DISK}1 /mnt/boot/efi
        ;;
esac

# Проверка
echo " "
echo "Результат разметки:"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT $DISK
echo " "
echo "Диск успешно подготовлен! смонтированно в /mnt"
echo "сейчас произведётся система Quasar-BASE, после этого вам предложится настройка"


basestrap /mnt base base-devel openrc elogind-openrc linux-zen linux-firmware-zen sudo vim nano grub os-prober efibootmgr dhcpcd wpasupplicant connman-openrc connman-gtk

if ! mount | grep -q '/mnt '; then
    echo "Система не смонтирована в /mnt! Сначала выполните разметку и монтирование."
    exit 1
fi

#!/bin/bash

# UEFI
if [ -d /sys/firmware/efi ]; then
    echo "Detected UEFI mode. Installing GRUB..."
    # GRUB
    basestrap /mnt grub efibootmgr
    artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=MyDistro
    artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "Detected BIOS mode. Installing Syslinux..."
    #Syslinux
    basestrap /mnt syslinux
    artix-chroot /mnt syslinux-install_update -i -a -m
fi
sed -i '/\[lib32\]/s/^#//' /mnt/etc/pacman.conf && sed -i '/Include/s/^#//' /mnt/etc/pacman.conf
artix-chroot /mnt

artix-chroot /mnt pacman -S $(cat pakege-list)
gpu_info=$(lspci -nn | grep -i 'VGA\|3D\|Display')

if echo "$gpu_info" | grep -qi "AMD"; then
        echo "Обнаружена видеокарта AMD"
        artix-chroot /mnt pacman -S $(cat pakege-amd)
    
elif echo "$gpu_info" | grep -qi "Intel"; then
	echo "Обнаружена видеокарта Intel"
	artix-chroot /mnt pacman -S $(cat pakege-intel)
    
elif echo "$gpu_info" | grep -qi "NVIDIA"; then
	echo "Обнаружена видеокарта NVIDIA"
	echo "не поддерживается"
	exit 1;
    
else
	echo "Видеокарта не определена! Информация:"
	echo "$gpu_info"
	echo "режим virgl"
fi

artix-chroot /mnt pacman -S $(cat pakege-list)


echo "первый этап завершён"
echo "это бета, выход!"
