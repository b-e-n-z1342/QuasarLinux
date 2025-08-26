#!/bin/bash

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
cfdisk "$DISK"

echo "=== РАЗДЕЛЫ НА ДИСКЕ ==="
fdisk -l "$DISK" | grep "^/dev"
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
printf '=%.0s' $(seq 1 $(tput cols))
echo "=== ФИНАЛЬНАЯ РАЗМЕТКА ==="
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT $DISK
echo " "
sleep 2
clear
# Дальнейшие шаги установки...
echo "Продолжаем установку системы..."
# Установка базовой системы
echo "Установка базовой системы..."
basestrap /mnt base base-devel openrc elogind-openrc mkinitcpio linux-zen linux-zen-headers dkms dbus dbus-openrc sudo nano ntfs-3g dosfstools dhcpcd mc htop wget curl git terminus-font pciutils 

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
chmod +x /mnt/etc/initcpio/hooks/quasar-branding
cp /mnt/etc/initcpio/hooks/quasar-branding  /usr/lib/initcpio/hooks/
chmod +x /mnt/usr/lib/initcpio/hooks/quasar-branding
sed -i '/^HOOKS=/ s/)/ quasar-branding)/' /mnt/etc/mkinitcpio.conf


cat << 'EOF' > /mnt/usr/lib/initcpio/install/quasar-branding
#!/bin/bash
hook_name="quasar-branding"

run_hook() {
    echo "Welcome to QuasarLinux-BETA"
}

build() {
    add_hook "$hook_name" run_hook
}

help() {
    cat <<-HELPEOF
This hook prints a welcome message for QuasarLinux-BETA.
HELPEOF
}
EOF



chmod +x /mnt/usr/lib/initcpio/install/quasar-branding

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
printf '=%.0s' $(seq 1 $(tput cols))
read -p "Введите имя нового пользователя: " USERNAME
artix-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME"
artix-chroot /mnt passwd $USERNAME
clear
printf '=%.0s' $(seq 1 $(tput cols))
echo "Создаём пароль для root"
artix-chroot /mnt passwd 
artix-chroot /mnt usermod -aG audio,video,input,storage,optical,lp,scanner $USERNAME
mkdir -p /mnt/home/$USERNAME
printf '=%.0s' $(seq 1 $(tput cols))
clear
artix-chroot /mnt /bin/bash << EOD
ROOT_PART=$(findmnt -n -o SOURCE /)
ROOT_DISK=$(lsblk -no PKNAME "$ROOT_PART")
ROOT_DISK="/dev/$ROOT_DISK"
ROOT_PART=$(mount | awk '$3 == "/" {print $1}')
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART") 
EOD
# Chroot-секция настройки ============================================================================================================================================================================
printf '=%.0s' $(seq 1 $(tput cols))

echo "Переход в chroot-окружение..."
sleep 2
artix-chroot /mnt /bin/bash << EOF

# Права доступа
chmod 600 /etc/{shadow,gshadow}
chown root:root /etc/{shadow,gshadow}

# Sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

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
chattr +i /usr/lib/os-release /etc/lsb-release 2>/dev/null || true
# Передача переменных в chroot
export UEFI_MODE=$UEFI_MODE
export DISK=$DISK
export BOOT_PART=$BOOT_PART
clear

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
    echo "!!! NVIDIA драйвера могут буть не стабильны и иметь проблемы с Wayland !!!"
    sleep 5
    pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils linux-firmware-nvidia
elif echo "\$gpu_info" | grep -qi "QXL"; then
    pacman -S qemu-guest-agent qemu-guest-agent-openrc --noconfirm
    rc-update add qemu-guest-agent default
elif echo "\$gpu_info" | grep -qi "Virtio"; then
    pacman -S --needed qemu-hw-display-virtio-gpu qemu-hw-display-virtio-gpu-gl qemu-hw-display-virtio-gpu-pci qemu-hw-display-virtio-gpu-pci-gl qemu-hw-display-virtio-gpu-pci-rutabaga qemu-hw-display-virtio-gpu-rutabaga --noconfirm
    pacman -S --needed qemu-hw-display-virtio-vga qemu-hw-display-virtio-vga-gl qemu-hw-display-virtio-vga-rutabaga qemu-hw-s390x-virtio-gpu-ccw virtiofsd vulkan-virtio lib32-vulkan-virtio --noconfirm
    rc-update add qemu-guest-agent default 
else
    echo "Видеокарта не определена, устанавливаю базовые драйверы"
    echo "осторожно низкая производительность!"
    sleep 5
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
printf '=%.0s' $(seq 1 $(tput cols))
function Kaliningrad() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Kaliningrad /etc/localtime
}
function Moscow() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
}
function Volgograd() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Volgograd  /etc/localtime
}
function Astrakhan() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Astrakhan /etc/localtime
}
function Saratov() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Saratov /etc/localtime
}
function Ulyanovsk() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Ulyanovsk /etc/localtime
}
function Samara() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Samara /etc/localtime
}
function Yekaterinburg() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Yekaterinburg /etc/localtime
}
function Omsk() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Omsk  /etc/localtime
}
function Krasnoyarsk() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Krasnoyarsk /etc/localtime
}
function Novokuznetsk() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Novokuznetsk /etc/localtime
}
function Irkutsk() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Irkutsk /etc/localtime
}
function Yakutsk() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Yakutsk /etc/localtime
}
function Chita() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Chita /etc/localtime
}
function Vladivostok() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Vladivostok /etc/localtime
}
function Ust-Nera() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Ust-Nera /etc/localtime
}
function Magadan() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Magadan /etc/localtime
}
function Kamchatka() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Kamchatka /etc/localtime
}
function Anadyr() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Anadyr /etc/localtime
}
function Sakhalin() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Sakhalin /etc/localtime
}
function Novosibirsk() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Novosibirsk /etc/localtime
}
function Tomsk() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Tomsk /etc/localtime
}
function Barnaul() {
    artix-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Barnaul /etc/localtime
}
echo "какое регеонное время вы хотите поставить?" 
echo "! ! ! В QuasarLinux пока что только регионны РФ ! ! !"
echo "
1) Калининград       9) Омск               17) Магадан
2) Москва           10) Красноярск         18) Камчатка
3) Волгоград        11) Новокузнецк        19) Анадырь
4) Астрахань        12) Иркутск            20) Сахалин
5) Саратов          13) Якутск             21) Новосибирск
6) Ульяновск        14) Чита               22) Томск
7) Самара           15) Владивосток        23) Барнаул
8) Екатеренбург     16) Усть-Нера
"
read -p "Выберите регион [1-23]: " local 
case $local in
    1) Kaliningrad ;;
    2) Moscow ;;
    3) Volgograd ;;
    4) Astrakhan ;;
    5) Saratov ;;
    6) Ulyanovsk ;;
    7) Samara ;;
    8) Yekaterinburg ;;  
    9) Omsk ;;
    10) Krasnoyarsk ;;
    11) Novokuznetsk ;;
    12) Irkutsk ;;
    13) Yakutsk ;;
    14) Chita ;;
    15) Vladivostok ;;
    16) Ust-Nera ;;
    17) Magadan ;;
    18) Kamchatka ;; 
    19) Anadyr ;;
    20) Sakhalin ;;
    21) Novosibirsk ;;
    22) Tomsk ;;
    23) Barnaul ;;
    *) echo "Неверный выбор. Выход." ;;
esac
artix-chroot /mnt hwclock --systohc
sleep 5
clear
printf '=%.0s' $(seq 1 $(tput cols))
artix-chroot /mnt pacman -Syy

mkinitcpio -P

ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
export ROOT_UUID
if [ "$UEFI_MODE" -eq 1 ]; then
    function grub() {
        artix-chroot /mnt pacman -S grub os-prober efibootmgr --noconfirm
        artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable --recheck
        artix-chroot /mnt sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Quasar Linux"/' /etc/default/grub || echo 'GRUB_DISTRIBUTOR="Quasar Linux"' >> /etc/default/grub
        artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    }
    
    function efistub() {
        artix-chroot /mnt pacman -S efibootmgr os-prober --noconfirm
        artix-chroot /mnt efibootmgr -b 0000 -B
        artix-chroot /mnt efibootmgr -c -d "$DISK" -p 1 -L "QuasarLinux" -l '\vmlinuz-linux-zen' -u 'root=UUID=$ROOT_UUID rw initrd=\initramfs-linux-zen.img'
    }
    function refind() {
        artix-chroot /mnt pacman -S efibootmgr os-prober refind --noconfirm
        artix-chroot /mnt refind-install
        artix-chroot /mnt tee /boot/efi/EFI/refind/refind.conf << EOF
timeout 5
default_selection "Quasar Linux"

# Скрыть пользовательский интерфейс rEFInd
hideui all

# Показать определенные элементы
showui banners,labels,bootprompt


# Разрешение экрана
resolution 1920x1080

# Размер иконок
icon_size 128

# Шрифт (можно изменить)
font_size 16

# Путь к теме (раскомментировать если есть тема)
#use_graphics_for linux,osx,windows
#banner hostname.bmp
#banner_scale fillscreen

# Цвета текста
text_mode true
selection_color cyan


# Сканировать все Linux ядра
scan_all_linux_kernels true

# Также сканировать вторичные файловые системы
also_scan_files ext4,vfat,btrfs

# Сканировать для других ОС
scanfor manual,external,optical

# Игнорировать определенные файлы
dont_scan_files vmlinuz.old,initrd.img.old

# Общие параметры ядра
extra_kernel_version_strings linux,linux-lts,linux-zen

# Параметры по умолчанию для всех Linux записей
extra_kernel_options root=UUID="$ROOT_UUID" rw quiet loglevel=3

# Инициализация (для OpenRC)
initrd /boot/initramfs-%v.img


# Основная запись Quasar Linux
menuentry "Quasar Linux" {
    icon /EFI/refind/icons/os_linux.png
    volume "QUASR_ROOT"
    loader /boot/vmlinuz-linux-zen
    initrd /boot/initramfs-linux-zen.img
    options "root=UUID="$ROOT_UUID" rw initrd=/boot/initramfs-linux.img quiet"
    enabled true
}
# Режим восстановления
menuentry "QuasarLinux falback" {
    icon /EFI/refind/icons/os_linux.png
    loader /boot/vmlinuz-linux-zen
    initrd /boot/initramfs-linux-zen-fallback.img
    options "root=UUID="$ROOT_UUID" rw single init=/bin/bash"
}

disable_autoboot no
disable_manual no

use_graphics_for linux,osx,windows


auto_detect_best_resolution true


usb_delay 2000

set ostype Linux
set rootpart UUID=ваш_uuid_root

showtools shutdown,reboot,firmware

tool shutdown {
    icon /EFI/refind/icons/shutdown.png
    loader /EFI/refind/icons/shutdown.efi
}

tool reboot {
    icon /EFI/refind/icons/reboot.png
    loader /EFI/refind/icons/reboot.efi
}

tool firmware {
    icon /EFI/refind/icons/firmware.png
    loader /EFI/refind/icons/firmware.efi
}

banner_message "Добро пожаловать в rEFInd Boot Manager"

bootprompt_message "Нажмите любую клавишу для меню загрузки..."

EOF
    }
    echo "Выберите загрузчик для EFI"
    echo "
    1) grub2 --рекомендуется из-за стабильности
    2) efistub 
    3) rEFInd
    "
    read -p "Какой ставить? [1-3]: " efi
    case $efi in
        1) grub ;;
        2) efistub ;;
        3) refind ;;
        *) echo "Неверный выбор, попробуйте ещё раз."
    esac
else
    function grub() {
        artix-chroot /mnt pacman -S grub os-prober --noconfirm
        artix-chroot /mnt grub-install --target=i386-pc --boot-directory=/boot --recheck /dev/"$DISK"
        artix-chroot /mnt sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Quasar Linux"/' /etc/default/grub || echo 'GRUB_DISTRIBUTOR="Quasar Linux"' >> /etc/default/grub
        artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    }
    function syslinux() { 
    artix-chroot /mnt pacman -S syslinux --noconfirm
    artix-chroot /mnt extlinux --install /boot
    artix-chroot /mnt dd if=/usr/lib/syslinux/bios/mbr.bin of=/dev/"$DISK" bs=440 count=1 conv=notrunc
    artix-chroot /mnt mkdir -p /boot/extlinux
    artix-chroot /mnt tee /boot/extlinux/extlinux.conf << EOFD
DEFAULT Quasarlinux
PROMPT 0
TIMEOUT 50

LABEL Quasarlinux
    KERNEL /vmlinuz-linux-zen
    APPEND root=UUID=$ROOT_UUID rw
    INITRD /initramfs-linux-zen.img
EOFD
    }
    echo "выберите загрузчик"
    echo "
    1) grub
    2) syslinux
    "
    read -p "какой ставить? [1-2]: " boot
    case $boot in
        1) grub ;;
        2) syslinux ;;
        *) echo "неверное число, попробуйте ещё раз." ;;
fi

sleep 2
clear
printf '=%.0s' $(seq 1 $(tput cols))
cp /root/QuasarLinux/INSTALL.sh /mnt/home/$USERNAME/
cp /root/QuasaarLinux/INST.sh /mnt/home/$USERNAME/



chmod +x /mnt/home/$USERNAME/INST.sh
chown $USERNAME:$USERNAME /mnt/home/$USERNAME/INST.sh
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
artix-chroot /mnt sh -c 'echo "Welcome to QuasarLinux" > /etc/motd'
artix-chroot /mnt mkinitcpio -P
sleep 2

read -p "Вы хотите зайти в chroot? (Y/n): " answer
case ${answer:0:1} in
    y|Y|"")
        artix-chroot /mnt
    ;;
    *)
        echo "OK"
    ;;
esac

umount /mnt/etc/resolv.conf
umount /mnt/proc
umount /mnt/sys
umount /mnt/dev
umount /mnt/run

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
