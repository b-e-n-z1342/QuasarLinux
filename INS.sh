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

# --- ОПЦИЯ РУЧНОЙ РАЗМЕТКИ ---
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

# Проверка
echo " "
echo "=== ФИНАЛЬНАЯ РАЗМЕТКА ==="
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT $DISK
echo " "

# Дополнительные опции
read -p "Форматировать SWAP раздел? (y/N): " make_swap
if [[ "$make_swap" =~ ^[Yy]$ ]]; then
    read -p "Введите раздел для SWAP (например, sda3): " SWAP_PART
    SWAP_PART="/dev/$SWAP_PART"
    mkswap $SWAP_PART
    swapon $SWAP_PART
    echo "SWAP активирован: $SWAP_PART"
fi

echo "Диск готов к установке! Продолжаем..."

# Установка базовой системы
echo "Установка базовой системы..."
basestrap /mnt base base-devel openrc elogind-openrc linux-zen sudo nano grub os-prober efibootmgr dhcpcd connman-openrc fish
rm -r /mnt/usr/share/
cp -r pixmap /mnt/usr/share/

# Настройка fstab
echo "Генерация fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab
cp /etc/pacman.conf /mnt/etc/
cp systemctl /mnt/usr/local/bin
chmod +x /mnt/usr/local/bin/systemctl
cp pakege-amd pakege-intel /mnt/
read -p "Введите имя нового пользователя: " USERNAME
artix-chroot /mnt useradd -m -G wheel -s /bin/fish "$USERNAME"

PASSWORD_HASH=$(openssl passwd -6 "quasar")

artix-chroot /mnt passwd $USERNAME
echo "давайте создадим пароль для root"
artix-chroot /mnt passwd 
artix-chroot /mnt usermod -aG audio,video,input $USERNAME

# Chroot-секция
echo "Переход в chroot-окружение..."
artix-chroot /mnt /bin/bash << EOF

chmod 600 /etc/{shadow,gshadow}
chown root:root /etc/{shadow,gshadow}

# Sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

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
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 quasar.localdomain quasar" >> /etc/hosts
echo 'NAME="Quasar Linux"
PRETTY_NAME="Quasar Linux (artix base)"
ID=quasar
ID_LIKE=artix
ANACONDA_ID="quasar"' > /etc/os-release

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
pacman -S --noconfirm $(cat pakege-list) pulseaudio pulseaudio-alsa seatd

usermod -aG seat sddm
mkdir -p /var/lib/sddm /var/run/sddm
chown sddm:sddm /var/lib/sddm /var/run/sddm
chmod 0755 /var/lib/sddm /var/run/sddm

echo "export XDG_SESSION_TYPE=wayland" | sudo tee -a /etc/environment
echo "export QT_QPA_PLATFORM=wayland" | sudo tee -a /etc/environment
echo "export MOZ_ENABLE_WAYLAND=1" | sudo tee -a /etc/environment
echo "[Wayland]" | sudo tee /etc/sddm.conf.d/wayland.conf
echo "EnableHiDPI=true" | sudo tee -a /etc/sddm.conf.d/wayland.conf
echo "SessionDir=/usr/share/wayland-sessions" | sudo tee -a /etc/sddm.conf.d/wayland.conf

EOF

artix-chroot /mnt tee /etc/init.d/pipewire-pulse << 'EOF'
#!/sbin/openrc-run
command="/usr/bin/pipewire-pulse"
command_user="root"usermod -aG seat sddm
pidfile="/run/pipewire-pulse.pid"
depend() {
    use pipewire
}
EOF
artix-chroot /mnt tee /etc/init.d/sddm <<'EOF'
#!/sbin/openrc-run

name="SDDM Display Manager"
description="Simple Desktop Display Manager"
command="/usr/bin/sddm"
command_args="--example-args"
command_user="root"
pidfile="/run/sddm.pid"

depend() {
    need dbus
    need elogind
    use udev
    need seatd  
    before alsa
    keyword -shutdown
}

start_pre() {
        if [ ! -f /etc/sddm.conf ]; then
        ewarn "Конфиг /etc/sddm.conf не найден! Создаю базовый"
        sddm --example-config > /etc/sddm.conf
    fi
    

    mkdir -p /var/run/sddm /var/lib/sddm
    chown sddm:sddm /var/run/sddm /var/lib/sddm
    chmod 0755 /var/run/sddm /var/lib/sddm
}

start_post() {
    elog "SDDM запущен. Проверьте журнал: journalctl -u sddm"
}

stop_post() {
    rm -f /var/run/sddm/* /tmp/runtime-sddm/*
}
EOF

artix-chroot /mnt tee /etc/pam.d/sddm <<'EOF'
auth        required    pam_env.so
auth        required    pam_permit.so
auth        required    pam_nologin.so
account     required    pam_permit.so
password    required    pam_deny.so
session     required    pam_loginuid.so
session     required    pam_env.so
session     required    pam_limits.so
session     required    pam_unix.so
EOF

artix-chroot /mnt tee /etc/init.d/pipewire << 'EOF'
#!/sbin/openrc-run
command="/usr/bin/pipewire"
command_user="root"
pidfile="/run/pipewire.pid"
depend() {
    need dbus
    need alsasound
}
EOF
artix-chroot /mnt tee /etc/security/limits.d/99-realtime.conf << 'EOF'
@audio - rtprio 99
@audio - memlock unlimited
EOF


artix-chroot /mnt /bin/fish << EOF

chmod +x /etc/init.d/sddm
chmod +x /etc/init.d/pipewire
chmod +x /etc/init.d/pipewire-pulse

rc-update add dbus boot
rc-update add udev boot
rc-update add elogind boot
rc-update add NetworkManager defaut
rc-update add sddm defaut
rc-update add acpid default
rc-update add alsa default
rc-update add seatd default
rc-update add pipewire default
rc-update add pipewire-pulse default
EOF




rm -rf /mnt/pakege-*
# Завершение
echo "Установка завершена!"
echo "Вы можете перезагрузить систему командой: reboot"
echo "Не забудьте извлечь установочный носитель"
