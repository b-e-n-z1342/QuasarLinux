#!/bin/bash

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
# pacstrap /mnt base linux linux-firmware ...
# Установка базовой системы
echo "Установка базовой системы..."
basestrap /mnt base base-devel openrc elogind-openrc linux-zen sudo nano grub os-prober efibootmgr dhcpcd networkmanager networkmanager-openrc fish mc htop wget curl git

# Копирование дополнительных файлов
if [ -d "pixmap" ]; then
    cp -r pixmap /mnt/usr/share/
fi

if [ -f "systemctl" ]; then
    cp systemctl /mnt/usr/local/bin/
    chmod +x /mnt/usr/local/bin/systemctl
fi

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
HOME_URL="https://quasarlinux.org"
SUPPORT_URL="https://quasarlinux.org/support"
BUG_REPORT_URL="https://quasarlinux.org/bugs"
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
    if [ ! -d /boot/efi/EFI/Quasar ]; then
        echo "ОШИБКА: GRUB не установился в EFI раздел!"
        exit 1
    fi
else
    echo "Установка GRUB для BIOS..."
    grub-install --target=i386-pc \$DISK --recheck
fi

# Генерация конфига GRUB с кастомным названием
sed -i 's/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Quasar Linux"/' /etc/default/grub || echo 'GRUB_DISTRIBUTOR="Quasar Linux"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Проверка установки GRUB
if [ ! -f /boot/grub/grub.cfg ]; then
    echo "ОШИБКА: Конфиг GRUB не создан!"
    exit 1
fi

# Детекция и установка драйверов GPU
echo "Определение видеокарты..."
gpu_info=\$(lspci -nn | grep -i 'VGA\|3D\|Display')
if echo "\$gpu_info" | grep -qi "AMD"; then
    echo "Обнаружена видеокарта AMD"
    pacman -S --noconfirm mesa vulkan-radeon libva-mesa-driver mesa-vdpau
elif echo "\$gpu_info" | grep -qi "Intel"; then
    echo "Обнаружена видеокарта Intel"
    pacman -S --noconfirm mesa vulkan-intel intel-media-driver libva-intel-driver
elif echo "\$gpu_info" | grep -qi "NVIDIA"; then
    echo "Обнаружена видеокарта NVIDIA"
    pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils
else
    echo "Видеокарта не определена, устанавливаю базовые драйверы"
    pacman -S --noconfirm mesa
fi

# Установка базовых системных пакетов
echo "Установка системных пакетов..."
pacman -S --noconfirm xorg-server xorg-xinit xorg-xrandr xorg-xauth xf86-input-libinput alsa-utils pulseaudio pulseaudio-alsa 

# Активация базовых сервисов
echo "Активация базовых OpenRC сервисов..."
rc-update add dbus boot
rc-update add udev boot
rc-update add elogind boot
rc-update add NetworkManager default
rc-update add acpid default
rc-update add alsa default

# Проверка активированных сервисов
echo "=== АКТИВИРОВАННЫЕ СЕРВИСЫ ==="
rc-update show
echo "=============================="

EOF

# Создание скрипта пост-установки
echo "Создание скрипта пост-установки..."
cat > /mnt/root/INST.sh << 'INST_EOF'
#!/bin/bash

echo "=========================================="
echo "    QUASAR LINUX - ПОСТ-УСТАНОВКА"
echo "=========================================="
echo ""
echo "Добро пожаловать в Quasar Linux!"
echo "Этот скрипт установит и настроит:"
echo "- KDE Plasma Desktop Environment"
echo "- SDDM Display Manager"
echo "- Дополнительные приложения"
echo "- Настройки системы"
read -p "Начать установку? (y/N): " start_install
if [[ ! "$start_install" =~ ^[Yy]$ ]]; then
    echo "Отмена установки"
    exit 0
fi



echo "установка Plasma"
sudo pacman -Syy


sudo pacman -S --noconfirm plasma sddm sddm-openrc dolphin qt6 wine-staging winetricks kcalc gwenview kate vlc konsole mesa vulkan-tools gamemode lib32-gamemode lib32-alsa-plugins  lib32-libpulse pipewire gst-plugins-base gst-plugins-good  gst-plugins-bad  gst-plugins-ugly xorg xorg-xinit pavucontrol networkmanager networkmanager-openrc sddm sddm-openrc



echo "Настройка SDDM..."
sudo groupadd -f sddm
sudo useradd -r -g sddm -s /usr/bin/nologin -d /var/lib/sddm sddm 2>/dev/null || true
sudo mkdir -p /var/lib/sddm /var/run/sddm
sudo chown sddm:sddm /var/lib/sddm /var/run/sddm
sudo chmod 0755 /var/lib/sddm /var/run/sddm
sudo usermod -aG seat,video,input sddm

# Создание OpenRC скрипта для SDDM
sudo tee /etc/init.d/sddm << 'SDDM_EOF'
#!/sbin/openrc-run

name="SDDM Display Manager"
description="Simple Desktop Display Manager"
command="/usr/bin/sddm"
command_user="root"
pidfile="/run/sddm.pid"

depend() {
    need dbus
    need elogind
    need NetworkManager
    use udev
    keyword -shutdown
}

start_pre() {
    if [ ! -f /etc/sddm.conf ]; then
        ewarn "Конфиг /etc/sddm.conf не найден! Создаю базовый"
        sddm --example-config > /etc/sddm.conf
    fi
    
    mkdir -p /var/run/sddm /var/lib/sddm /tmp/runtime-sddm
    chown sddm:sddm /var/run/sddm /var/lib/sddm /tmp/runtime-sddm
    chmod 0755 /var/run/sddm /var/lib/sddm
    chmod 0700 /tmp/runtime-sddm
    
    export XDG_RUNTIME_DIR="/tmp/runtime-sddm"
}

start_post() {
    einfo "SDDM запущен успешно"
}

stop_post() {
    rm -rf /var/run/sddm/* /tmp/runtime-sddm/* 2>/dev/null || true
}
SDDM_EOF

sudo chmod +x /etc/init.d/sddm

# Настройка SDDM конфига
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/quasar.conf << 'SDDM_CONF_EOF'
[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[X11]
SessionDir=/usr/share/xsessions
XauthPath=/usr/bin/xauth

[Wayland]
SessionDir=/usr/share/wayland-sessions
EnableHiDPI=true
SDDM_CONF_EOF

# Активация SDDM
echo "Активация SDDM..."
sudo rc-update add sddm default

echo "Настройка звука..."
sudo pacman -S --noconfirm pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber

# Создание OpenRC скрипта для pipewire
sudo tee /etc/init.d/pipewire << 'PIPEWIRE_EOF'
#!/sbin/openrc-run
command="/usr/bin/pipewire"
command_user="root"
pidfile="/run/pipewire.pid"
depend() {
    need dbus
    need alsasound
}
EOF

sudo chmod +x /etc/init.d/pipewire
sudo rc-update add pipewire default

echo "Настройка темы и локализации..."
sudo pacman -S --noconfirm plasma-localization-ru kde-l10n-ru

echo "Финальная настройка системы..."
# Добавляем пользователя в нужные группы
sudo usermod -aG wheel,audio,video,input,storage,optical,lp,scanner,games $(whoami)

# Настройка .bashrc для пользователя
cat >> ~/.bashrc << 'BASHRC_EOF'
# Quasar Linux приветствие
echo "Добро пожаловать в Quasar Linux!"
echo "Версия: $(cat /etc/os-release | grep VERSION= | cut -d'=' -f2 | tr -d '"')"
echo ""
BASHRC_EOF

echo "=========================================="
echo "         УСТАНОВКА ЗАВЕРШЕНА!"
echo "=========================================="
echo ""
echo "Quasar Linux успешно настроен!"
echo "Рекомендуется перезагрузить систему:"
echo "sudo reboot"
echo ""
echo "После перезагрузки вас встретит графический"
echo "интерфейс SDDM с KDE Plasma"
echo ""
echo "Удачи с использованием Quasar Linux! 🚀"
echo ""
INST_EOF

chmod +x /mnt/home/$USERNAME/INST.sh
chown $USERNAME:$USERNAME /mnt/home/$USERNAME/INST.sh

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

# Размонтирование
echo "Размонтирование разделов..."
umount -R /mnt 2>/dev/null || true
swapoff $SWAP_PART 2>/dev/null || true

echo "=========================================="
echo "      УСТАНОВКА QUASAR LINUX ЗАВЕРШЕНА!"
echo "=========================================="
echo ""
echo "Базовая система успешно установлена!"
echo ""
echo "ЧТО БЫЛО УСТАНОВЛЕНО:"
echo "- Загрузчик GRUB настроен и работает"
echo "- Базовая система с консольными утилитами"
echo "- Сетевые настройки (NetworkManager)" 
echo "- Пользователь: $USERNAME"
echo "- Совместимость systemctl команд"
echo ""
echo "СЛЕДУЮЩИЕ ШАГИ:"
echo "1. Перезагрузите систему: reboot"
echo "2. Войдите как пользователь: $USERNAME"
echo "3. Запустите: ./INST.sh"
echo "4. Установите KDE Plasma и приложения"
echo ""
echo "ВНИМАНИЕ: Не забудьте извлечь установочный носитель!"
echo ""
echo "Добро пожаловать в Quasar Linux! 🚀"
echo "=========================================="
