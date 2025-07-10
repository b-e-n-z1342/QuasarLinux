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

# Проверка поддержки UEFI
if [ -d /sys/firmware/efi/efivars ]; then
    echo "Обнаружен режим загрузки: UEFI"
    UEFI_MODE=1
else
    echo "Обнаружен режим загрузки: BIOS"
    UEFI_MODE=0
fi

# Выбор диска
echo "Доступные диски:"
lsblk -d -o NAME,SIZE,MODEL,TYPE
read -p "Введите имя диска (например, sda/nvme0n1): " DISK
DISK="/dev/$DISK"

# Проверка существования диска
if [ ! -e "$DISK" ]; then
    echo "Ошибка: диск $DISK не существует!"
    exit 1
fi

# Подтверждение
read -p "ВСЕ ДАННЫЕ НА $DISK БУДУТ УДАЛЕНЫ! Продолжить? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Отмена"
    exit 0
fi

# Очистка диска
echo "Очистка диска..."
wipefs -a -f $DISK
partprobe $DISK

# Разметка диска
if [ $UEFI_MODE -eq 1 ]; then
    echo "Создание GPT разметки..."
    parted -s $DISK mklabel gpt
    parted -s $DISK mkpart "EFI" fat32 1MiB 513MiB
    parted -s $DISK set 1 esp on
    parted -s $DISK mkpart "ROOT" ext4 513MiB 100%
    PART_BOOT="${DISK}p1"
    PART_ROOT="${DISK}p2"
else
    echo "Создание MBR разметки..."
    parted -s $DISK mklabel msdos
    parted -s $DISK mkpart primary ext4 1MiB 513MiB
    parted -s $DISK set 1 boot on
    parted -s $DISK mkpart primary ext4 513MiB 100%
    PART_BOOT="${DISK}1"
    PART_ROOT="${DISK}2"
fi

# Форматирование разделов
echo "Форматирование разделов..."
if [ $UEFI_MODE -eq 1 ]; then
    mkfs.fat -F32 $PART_BOOT
else
    mkfs.ext4 $PART_BOOT
fi
mkfs.ext4 $PART_ROOT

# Монтирование
echo "Монтирование разделов..."
mount $PART_ROOT /mnt
if [ $UEFI_MODE -eq 1 ]; then
    mkdir -p /mnt/boot/efi
    mount $PART_BOOT /mnt/boartix-chroot /mnt/efi
else
    mkdir -p /mnt/boot
    mount $PART_BOOT /mnt/boot
fi

# Проверка
echo " "
echo "Результат разметки:"
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT $DISK
echo " "

# Установка базовой системы
echo "Установка базовой системы..."
basestrap /mnt base base-devel openrc elogind-openrc \
    linux-zen \
    sudo nano grub os-prober efibootmgr \
    dhcpcd connman-openrc

read -p "Введите имя нового пользователя: " USERNAME

# Настройка fstab
echo "Генерация fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab
cp /etc/pacman.conf /mnt/etc/

# Chroot-секция
echo "Переход в chroot-окружение..."
cat << EOF | artix-chroot /mnt /bin/bash

# Настройка времени
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Локализация
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

# Сеть
echo "quasarlinux" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 quasar.localdomain quasar" >> /etc/hosts
echo 'NAME="Quasar Linux"
PRETTY_NAME="Quasar Linux (artix base)"
ID=quasar
ID_LIKE=artix
ANACONDA_ID="quasar"' > /etc/os-release

echo "root:password" | chpasswd

# Пользователь
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "Установка пароля для пользователя "$USERNAME":"
passwd "$USERNAME"

# Sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Загрузчик
if [ $UEFI_MODE -eq 1 ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Quasar
else
    grub-install $DISK
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Драйверы GPU
gpu_info=\$(lspci -nn | grep -i 'VGA\|3D\|Display')
if echo "\$gpu_info" | grep -qi "AMD"; then
    echo "Обнаружена видеокарта AMD"
    pacman -S --noconfirm $(cat pakege-amd)
elif echo "\$gpu_info" | grep -qi "Intel"; then
    echo "Обнаружена видеокарта Intel"
    pacman -S --noconfirm $(cat pakege-intel)
elif echo "\$gpu_info" | grep -qi "NVIDIA"; then
    echo "Обнаружена видеокарта NVIDIA"
    pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils
else
    echo "Видеокарта не определена"
fi

# Дополнительные пакеты
pacman -S --noconfirm xorg xorg-xinit plasma dolphin konsole  \
    firefox pipewire pavucontrol networkmanager networkmanager-openrc

# Сервисы
rc-update add connmand
rc-update add sddm
rc-update add NetworkManager
rc-update add elogind

EOF

# Завершение
echo "Установка завершена!"
echo "Вы можете перезагрузить систему командой: reboot"
echo "Не забудьте извлечь установочный носитель"
