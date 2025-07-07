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
read -p "Введите имя диска (например, sda/nvme0n1): " DISK
DISK="/dev/$DISK"

# Проверка существования диска
if [ ! -e "$DISK" ]; then
    echo "Ошибка: диск $DISK не существует!"
    exit 1
fi

# Выбор схемы разметки
PS3='Выберите схему разметки: '
options=("MBR (BIOS)" "GPT (UEFI)" "Отмена")
select opt in "${options[@]}"
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

# Очистка диска
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

# Определение типа прошивки
check_uefi() {
    if [ -d "/sys/firmware/efi" ]; then
        return 0   # UEFI
    else
        return 1   # BIOS
    fi
}

# Установка GRUB
install_grub() {
    if check_uefi; then
        echo "Обнаружен режим UEFI. Установка GRUB для UEFI..."
        
        # Установка необходимых пакетов
        artix-chroot /mnt pacman -S grub efibootmgr os-prober --noconfirm
        
        # Определение ESP раздела
        ESP_PART=$(lsblk -lpo parttype,name | grep -i 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b' | awk '{print $2}')
        
        if [ -z "$ESP_PART" ]; then
            echo "Ошибка: ESP раздел не найден!"
            exit 1
        fi
        
        # Монтирование ESP (если ещё не смонтирован)
        if ! mount | grep -q '/mnt/boot/efi'; then
            mkdir -p /mnt/boot/efi
            mount $ESP_PART /mnt/boot/efi
        fi
        
        # Установка GRUB
        artix-chroot /mnt grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot/efi \
            --bootloader-id=GRUB \
            --recheck
        
        # Включение os-prober
        sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /mnt/etc/default/grub
    else
        echo "Обнаружен режим BIOS. Установка GRUB для BIOS..."
        
        # Установка пакетов
        artix-chroot /mnt pacman -S grub os-prober --noconfirm
        
        # Определение корневого диска
        ROOT_DISK=$(lsblk -lpo pkname,mountpoint | awk '$2=="/mnt" {print $1}')
        
        if [ -z "$ROOT_DISK" ]; then
            echo "Ошибка: не удалось определить корневой диск!"
            exit 1
        fi
        
        # Установка GRUB
        artix-chroot /mnt grub-install \
            --target=i386-pc \
            --recheck \
            $ROOT_DISK
    fi
    
    # Генерация конфигурации GRUB
    artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    
    echo "GRUB успешно установлен!"
}

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
