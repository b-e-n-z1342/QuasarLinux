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

# Ручная разметка только через cfdisk
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

# Форматирование разделов
echo "Форматирование разделов..."
if [ $UEFI_MODE -eq 1 ]; then
    echo "Форматирование EFI: $BOOT_PART"
    mkfs.fat -F32 $BOOT_PART
else
    echo "Форматирование BOOT: $BOOT_PART"
    mkfs.ext2 -F $BOOT_PART
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
clear
echo "=== ФИНАЛЬНАЯ РАЗМЕТКА ==="
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT $DISK
echo " "
sleep 2
clear
# Дальнейшие шаги установки...
echo "Продолжаем установку системы..."
# Установка базовой системы
echo "Установка базовой системы..."
basestrap /mnt base base-devel openrc elogind-openrc mkinitcpio linux-zen linux-zen-headers dkms dbus dbus-openrc sudo nano  dhcpcd mc htop wget curl git terminus-font pciutils 

# Копирование дополнительных файлов
[ -d /mnt/usr/share/pixmaps ] && rm -r /mnt/usr/share/pixmaps

sleep 1
cp -r pixmap /mnt/usr/share/
cd /mnt/usr/share/
mv pixmap pixmaps
cd 
sleep 1 
cat << 'EOFRC' > /mnt/etc/sysctl.d/99-quasar.conf
kernel.hostname = QuasarLinux
EOFRC


cat << 'EOF' > /mnt/etc/initcpio/hooks/quasar-branding 
run_hook() {
    echo "Welcom to QuasarLinux-BETA" > /etc/issue
}
EOF

cp /mnt/etc/initcpio/hooks/quasar-branding  /usr/lib/initcpio/hooks/

sed -i '/^HOOKS=/ s/)/ quasar-branding)/' /mnt/etc/mkinitcpio.conf



cp /etc/issue /mnt/etc/

# Настройка fstab
mount --types proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev
mount --rbind /run /mnt/run

clear
echo "Генерация fstab..."
mkdir -p /mnt/etc
fstabgen -U /mnt >> /mnt/etc/fstab
cp /etc/pacman.conf /mnt/etc/
clear
# Создание пользователя
echo "================================================================="
read -p "Введите имя нового пользователя: " USERNAME
artix-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME"
artix-chroot /mnt passwd $USERNAME
clear
echo "================================================================="
echo "Создаём пароль для root"
artix-chroot /mnt passwd 
artix-chroot /mnt usermod -aG audio,video,input,storage,optical,lp,scanner $USERNAME
mkdir -p /mnt/home/$USERNAME
echo "================================================================="
clear


# Chroot-секция настройки ============================================================================================================================================================================


echo "========================================================================================================================="
echo "Переход в chroot-окружение..."
sleep 2
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
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^#\(ru_RU.UTF-8 UTF-8\)/\1/' /etc/locale.gen

locale-gen
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

# Сеть
echo "quasar-pc" > /etc/hostname
cat > /etc/hosts << 'HOSTS_EOF'
127.0.0.1 localhost
::1 localhost
127.0.1.1 quasarlinux.localdomain quasarlinux
HOSTS_EOF

pacman -S networkmanager networkmanager-openrc

# Полный ребрендинг системы
cat > /usr/lib/os-release << 'OS_EOF'
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
[ -d /etc/update-motd.d/ ] && rm -rf /etc/update-motd.d/

# Симлинк для совместимости
ln -sf /etc/os-release /usr/lib/os-release 2>/dev/null || true

# Передача переменных в chroot
export UEFI_MODE=$UEFI_MODE
export DISK=$DISK
export BOOT_PART=$BOOT_PART
clear

sleep 5
# Детекция и установка драйверов GPU
echo "Определение виsudo extlinux --install /boot
деокарты..."
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
pacman -S --noconfirm xorg alsa-utils kbd pipewire pipewire-alsa pipewire-pulse acpid
sleep 2
# Активация базовых сервисов
echo "Активация базовых OpenRC сервисов..."
rc-update add dbus default
rc-update add udev default
rc-update add elogind default
rc-update add acpid default



EOF
sleep 5
clear
echo "==========================================================================================================================="
cat > /mnt/install-grub.sh << 'EOF'
#!/bin/bash

set -eux
# Определяем режим загрузки
UEFI_MODE=\[ -d /sys/firmware/efi ] && echo 1 || echo 0

# Ставим GRUB
if [ "$UEFI_MODE" -eq 1 ]; then
    pacman -Sy grub os-prober efibootmgr --noconfirm
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable --recheck
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Quasar Linux"/' /etc/default/grub || echo 'GRUB_DISTRIBUTOR="Quasar Linux"' >> /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
else
    ROOT_PART=$(findmnt -n -o SOURCE /)
    ROOT_DISK=$(lsblk -no PKNAME "$ROOT_PART")
    ROOT_DISK="/dev/$ROOT_DISK"
    ROOT_PART=$(mount | awk '$3 == "/" {print $1}')
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART") 
    pacman -Sy syslinux --noconfirm
    extlinux --install /boot
    dd if=/usr/lib/syslinux/bios/mbr.bin of="$ROOT_DISK" bs=440 count=1 conv=notrunc
    mkdir /boot/syslinux
    cat > /boot/syslinux/syslinux.cfg << EOFD
DEFAULT Quasarlinux
PROMPT 0
TIMEOUT 50

LABEL Quasarlinux
    KERNEL /vmlinuz-linux-zen
    APPEND root=UUID=$ROOT_UUID rw
    INITRD /initramfs-linux-zen.img
EOFD
    
fi
EOF

chmod +x /mnt/install-grub.sh

artix-chroot /mnt bash /install-grub.sh 2>&1 | tee /grub-install.log
sleep 2
clear
echo "========================================================================================================================="
cp INSTALL.sh /mnt/home/$USERNAME/
cp INST.sh /mnt/home/$USERNAME/



chmod +x /mnt/home/$USERNAME/INST.sh
chown $USERNAME:$USERNAME /mnt/home/$USERNAME/INST.sh
cp INSTALL.sh /mnt/home/$USERNAME/

chmod +x /mnt/home/$USERNAME/INSTALL.sh
chown $USERNAME:$USERNAME /mnt/home/$USERNAME/INSTALL.sh


echo "FONT=ter-v16n" >> /mnt/etc/vconsole.conf

artix-chroot /mnt rc-update add NetworkManager default 


chown $USERNAME:$USERNAME /mnt/home/$USERNAME/README.txt




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
[ -n "${SWAP_PART+x}" ] && swapoff "$SWAP_PART" 2>/dev/null

echo "=========================================="
echo "      УСТАНОВКА QUASAR LINUX ЗАВЕРШЕНА!"
echo "=========================================="
echo "Базовая система успешно установлена!"
echo "ЧТО БЫЛО УСТАНОВЛЕНО:"
echo "- Загрузчик GRUB настроен и работает"
echo "- Базовая система с консольными утилитами"
echo "- Сетевые настройки (NetworkManager)"
echo "- Пользователь: $USERNAME"
echo "СЛЕДУЮЩИЕ ШАГИ:"
echo "1. Перезагрузите систему: reboot"
echo "2. Войдите как пользователь: $USERNAME"
echo "3. автоматом запустится пост установка"
echo "4. Установите KDE Plasma и приложения"
echo "ВНИМАНИЕ: Не забудьте извлечь установочный носитель!"
echo "Добро пожаловать в Quasar Linux! 🚀"
echo "=========================================="
