#!/bin/bash
pacman -Sy terminus-font --noconfirm
setfont ter-v20n
sleep 2

echo "
██████╗ ██╗   ██╗ █████╗ ███████╗ █████╗ ██████╗ 
██╔═══██╗██║   ██║██╔══██╗██╔════╝██╔══██╗██╔══██╗
██║   ██║██║   ██║███████║███████╗███████║██████╔╝
██║▄▄ ██║██║   ██║██╔══██║╚════██║██╔══██║██╔══██╗
╚██████╔╝╚██████╔╝██║  ██║███████║██║  ██║██║  ██║
 ╚══▀▀═╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
"


# Определение режима загрузки (UEFI/BIOS)
UEFI_MODE=0
[ -d /sys/firmware/efi ] && UEFI_MODE=1

echo "Доступные диски:"
lsblk -d -o NAME,SIZE,MODEL,TYPE
read -p "Введите имя диска (например, sda/nvme0n1): " DISK
DISK="/dev/$DISK"

# Проверка существования диска
if [ ! -e "$DISK" ]; then
    echo "Ошибка: диск $DISK не существует!"
    exit 1
fi

# Проверка готовности диска
read -p "Диск уже подготовлен (разделы созданы и смонтированы)? [y/N]: " PREPARED
if [[ "$PREPARED" =~ ^[Yy]$ ]]; then
    echo "Пропускаем разметку и монтирование..."
    
    # Проверка корректности монтирования
    if ! mount | grep -q '/mnt '; then
        echo "Ошибка: корневая файловая система не смонтирована в /mnt!"
        exit 1
    fi
    
    if [ $UEFI_MODE -eq 1 ] && ! mount | grep -q '/mnt/boot/efi'; then
        echo "Ошибка: EFI раздел не смонтирован в /mnt/boot/efi!"
        exit 1
    fi
    
    echo "Текущая разметка:"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT $DISK
else
    # Подтверждение операции
    read -p "ВСЕ ДАННЫЕ НА $DISK БУДУТ УДАЛЕНЫ! Продолжить? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Отмена"
        exit 0
    fi

    # --- РУЧНАЯ ИЛИ АВТОМАТИЧЕСКАЯ РАЗМЕТКА ---
    read -p "Ручная разметка (y) или авто (N)? " manual_part
    if [[ "$manual_part" =~ ^[Yy]$ ]]; then
        echo "Запускаю cfdisk для ручной разметки $DISK..."
        cfdisk $DISK

        echo "=== РАЗДЕЛЫ НА ДИСКЕ ==="
        fdisk -l $DISK | grep "^/dev"
        echo "======================="

        # Выбор раздела под корень /
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
    else
        # --- АВТОМАТИЧЕСКАЯ РАЗМЕТКА ---
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
            BOOT_PART="${DISK}p1"
            ROOT_PART="${DISK}p2"
        else
            echo "Создание MBR разметки..."
            parted -s $DISK mklabel msdos
            parted -s $DISK mkpart primary ext4 1MiB 513MiB
            parted -s $DISK set 1 boot on
            parted -s $DISK mkpart primary ext4 513MiB 100%
            BOOT_PART="${DISK}1"
            ROOT_PART="${DISK}2"
        fi
    fi

    # Форматирование разделов
    echo "Форматирование разделов..."
    if [ $UEFI_MODE -eq 1 ]; then
        echo "Форматирование EFI: $BOOT_PART"
        mkfs.fat -F32 $BOOT_PART
    else
        echo "Форматирование BOOT: $BOOT_PART"
        mkfs.ext4 -F $BOOT_PART
    fi

    echo "Форматирование ROOT: $ROOT_PART"
    mkfs.ext4 -F $ROOT_PART

    # Монтирование
    echo "Монтирование разделов..."
    mount $ROOT_PART /mnt

    if [ $UEFI_MODE -eq 1 ]; then
        mkdir -p /mnt/boot/efi
        mount $BOOT_PART /mnt/boot/efi
    else
        mkdir -p /mnt/boot
        mount $BOOT_PART /mnt/boot
    fi

    # Проверка монтирования
    echo " "
    echo "=== ФИНАЛЬНАЯ РАЗМЕТКА ==="
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT $DISK
    echo " "
fi

# --- ОБЩИЕ ОПЕРАЦИИ (ВЫПОЛНЯЮТСЯ ВСЕГДА) ---

# Работа со SWAP
read -p "Активировать SWAP раздел? [y/N]: " make_swap
if [[ "$make_swap" =~ ^[Yy]$ ]]; then
    read -p "Введите раздел для SWAP (например, sda3): " SWAP_PART
    SWAP_PART="/dev/$SWAP_PART"
    
    if [ ! -e "$SWAP_PART" ]; then
        echo "Ошибка: раздел $SWAP_PART не существует!"
    else
        mkswap $SWAP_PART
        swapon $SWAP_PART
        echo "SWAP активирован: $SWAP_PART"
    fi
fi

# Дальнейшие шаги установки...
echo "Продолжаем установку системы..."
# Установка базовой системы
echo "Установка базовой системы..."
basestrap /mnt base base-devel runit elogind-runit runit-rc dhcpcd linux-zen linux-zen-headers dkms dbus sudo nano grub os-prober efibootmgr dhcpcd mc htop wget curl git iwd terminus-font

# Копирование дополнительных файлов
rm -r /mnt/usr/share/pixmap
sleep 1
cp -r pixmap /mnt/usr/share/

\

# Настройка fstab
echo "Генерация fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab
cp /etc/pacman.conf /mnt/etc/

# Создание пользователя
read -p "Введите имя нового пользователя: " USERNAME
artix-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME"
artix-chroot /mnt passwd $USERNAME
echo "Создаём пароль для root"
artix-chroot /mnt passwd 
artix-chroot /mnt usermod -aG audio,video,input,storage,optical,lp,scanner $USERNAME

mount --types proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev
mount --rbind /run /mnt/run

# Chroot-секция настройки
echo "Переход в chroot-окружение..."
artix-chroot /mnt /bin/bash << EOF

# Права доступа
chmod 600 /etc/{shadow,gshadow}
chown root:root /etc/{shadow,gshadow}

# Sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

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
cat > /etc/hosts << 'HOSTS_EOF'
127.0.0.1 localhost
::1 localhost
127.0.1.1 quasarlinux.localdomain quasarlinux
HOSTS_EOF

pacman -S networkmanager networkmanager-runit

# Полный ребрендинг системы
cat > /etc/os-release << 'OS_EOF'
NAME="Quasar Linux"
PRETTY_NAME="Quasar Linux (Artix base)"
ID=quasar
ID_LIKE=artix
ANACONDA_ID="quasar"
VERSION="1.0"
VERSION_ID="1.0"
BUILD_ID="rolling"
ANSI_COLOR="0;36"
HOME_URL="https://b-e-n-z1342.github.io"
LOGO=quasar-logo
OS_EOF

cat > /etc/lsb-release << 'LSB_EOF'
DISTRIB_ID=Quasar
DISTRIB_RELEASE=1.0
DISTRIB_DESCRIPTION="Quasar Linux"
DISTRIB_CODENAME=rolling
LSB_EOF

# Принудительная настройка issue
echo "Quasar Linux \\r \\l" > /etc/issue
echo "Quasar Linux" > /etc/issue.net
echo "Welcome to Quasar Linux!" > /etc/motd

# Убираем автогенерацию
rm -rf /etc/update-motd.d/ 2>/dev/null || true

# Симлинк для совместимости
ln -sf /etc/os-release /usr/lib/os-release 2>/dev/null || true

# Передача переменных в chroot
export UEFI_MODE=$UEFI_MODE
export DISK=$DISK
export BOOT_PART=$BOOT_PART

# Установка GRUB
echo "Устанавливаю загрузчик GRUB..."
if [ \$UEFI_MODE -eq 1 ]; then
    echo "Установка GRUB для UEFI..."
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
    if [ ! -d /boot/efi/EFI/GRUB ]; then
        echo "ОШИБКА: GRUB не установился в EFI раздел!"
        exit 1
    fi
else
    echo "Установка GRUB для BIOS..."
    grub-install --target=i386-pc \$DISK --recheck
fi
sleep 5
# Генерация конфига GRUB с кастомным названием
sed -i 's/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Quasar Linux"/' /etc/default/grub || echo 'GRUB_DISTRIBUTOR="Quasar Linux"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Проверка установки GRUB
if [ ! -f /boot/grub/grub.cfg ]; then
    echo "ОШИБКА: Конфиг GRUB не создан!"
    exit 1
fi
sleep 5
# Детекция и установка драйверов GPU
echo "Определение видеокарты..."
gpu_info=\$(lspci -nn | grep -i 'VGA\|3D\|Display')
if echo "\$gpu_info" | grep -qi "AMD"; then
    echo "Обнаружена видеокарта AMD"
    pacman -S --noconfirm mesa vulkan-radeon libva-mesa-driver mesa-vdpau linux-firmware-amdgpu
elif echo "\$gpu_info" | grep -qi "Intel"; then
    echo "Обнаружена видеокарта Intel"
    pacman -S --noconfirm mesa vulkan-intel intel-media-driver libva-intel-driver linux-firmware-intel
elif echo "\$gpu_info" | grep -qi "NVIDIA"; then
    echo "Обнаружена видеокарта NVIDIA"
    pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils linux-firmware-nvidia
else
    echo "Видеокарта не определена, устанавливаю базовые драйверы"
    pacman -S --noconfirm mesa
fi

# Установка базовых системных пакетов
echo "Установка системных пакетов..."
pacman -S --noconfirm acpid xorg-server xorg-xinit xorg-xrandr xorg-xauth xf86-input-libinput alsa-utils kbd pipewire pipewire-alsa pipewire-pulse acpid xorg
sleep 2
# Активация базовых сервисов
echo "Активация базовых OpenRC сервисов..."
ln -s /etc/sv/dbus /etc/runit/runsvdir/default/
ln -s /etc/sv/udev /etc/runit/runsvdir/default/
ln -s /etc/sv/elogind /etc/runit/runsvdir/default/
ln -s /etc/sv/acpid /etc/runit/runsvdir/default/
ln -s /etc/sv/alsa /etc/runit/runsvdir/default/

# Проверка активированных сервисов
echo "=== АКТИВИРОВАННЫЕ СЕРВИСЫ ==="
rc-update show
echo "=============================="

EOF
cp INSTALL.sh /mnt/root/
cp INSTALL.sh /mnt/home/$USERNAME/

cp INST.sh /mnt/root/
cp INST.sh /mnt/home/$USERNAME/


chmod +x /mnt/root/INST.sh
chmod +x /mnt/home/$USERNAME/INST.sh
chown $USERNAME:$USERNAME /mnt/home/$USERNAME/INST.sh
cp INSTALL.sh /mnt/home/$USERNAME/
chmod +x /mnt/home/$USERNAME/INSTALL.sh

echo "FONT=ter-v16n" >> /mnt/etc/vconsole.conf
cat << 'EOF' > /mnt/etc/NetworkManager/conf.d/wifi_backend.conf
[device]
wifi.backend=iwd
EOF
artix-chroot /mnt rc-update add NetworkManager default

# Создание информационного файла
cat > /mnt/home/$USERNAME/README.txt << README_EOF
===========================================
      ДОБРО ПОЖАЛОВАТЬ В QUASAR LINUX!
===========================================

Базовая установка завершена успешно!

ЧТО УСТАНОВЛЕНО:
- Базовая система Quasar Linux
- Консольные утилиты (mc, htop, nano)
- Сетевые инструменты (NetworkManager)
- Базовые драйверы видеокарты
- Звуковая подсистема (ALSA)

СЛЕДУЮЩИЕ ШАГИ:
1. Перезагрузите систему: sudo reboot
2. Войдите в систему через консоль
3. Запустите: ./INST.sh
4. Следуйте инструкциям для установки KDE Plasma

СПРАВКА:
- Команды systemctl работают (совместимость с OpenRC)
- Файлы конфигурации в /etc/
- Логи системы: sudo journalctl или dmesg

ПОДДЕРЖКА:
- Документация: /usr/share/doc/quasar/
- Сообщество: https://quasarlinux.org

Удачи! 🚀
README_EOF

chown $USERNAME:$USERNAME /mnt/home/$USERNAME/README.txt


cat << 'EOF' > /mnt/etc/initcpio/hooks/Quasar-branding 
run_hook() {
    echo "Welcom to QuasarLinux-BETA"
}
EOF





grep -q 'Quasar-branding' /mnt/etc/mkinitcpio.conf
sed -i 's/HOOKS=(\(.*\))/HOOKS=(\1 Quasar-branding)/' /mnt/etc/mkinitcpio.conf

cat << 'EOF' >> /mnt/home/$USERNAME/.bashrc
if [ ! -f ~/.Quasar_post_done ]; then
    ./INSTALL.sh
    touch ~/.Quasar_post_done
fi
EOF






artix-chroot /mnt mkinitcpio -P

# Размонтирование
echo "Размонтирование разделов..."
umount -R /mnt 2>/dev/null || true
swapoff $SWAP_PART 2>/dev/null || true

echo "=========================================="
echo "      УСТАНОВКА QUASAR LINUX ЗАВЕРШЕНА!"
echo "=========================================="
echo "Базовая система успешно установлена!"
echo "ЧТО БЫЛО УСТАНОВЛЕНО:"
echo "- Загрузчик GRUB настроен и работает"
echo "- Базовая система с консольными утилитами"
echo "- Сетевые настройки (NetworkManager)" 
echo "- Пользователь: $USERNAME"
echo "- Совместимость systemctl команд"
echo "СЛЕДУЮЩИЕ ШАГИ:"
echo "1. Перезагрузите систему: reboot"
echo "2. Войдите как пользователь: $USERNAME"
echo "3. Запустите: ./INSTALL.sh"
echo "4. Установите KDE Plasma и приложения"
echo "ВНИМАНИЕ: Не забудьте извлечь установочный носитель!"
echo "Добро пожаловать в Quasar Linux! 🚀"
echo "=========================================="
