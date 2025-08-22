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
# Функция для вывода цветного текста
print_message() {
    echo -e "\e[1;32m$1\e[0m"
}

# Функция для вывода ошибок
print_error() {
    echo -e "\e[1;31mОшибка: $1\e[0m"
}

# Функция для проверки существования устройства
check_device() {
    if [ ! -e "$1" ]; then
        print_error "Устройство $1 не существует!"
        exit 1
    fi
}

# Основное меню
echo "Что вы хотите сделать?"
select option in "Chroot в существующую систему" "Установка QuasarLinux" "Выход"; do
    case $option in
        "Chroot в существующую систему")
            chroot_system
            break
            ;;
        "Установка QuasarLinux")
            install_system
            break
            ;;
        "Выход")
            echo "Выход из скрипта"
            exit 0
            ;;
        *)
            echo "Некорректный выбор, повторите"
            ;;
    esac
done

# Функция для chroot
chroot_system() {
    # Показ доступных разделов
    print_message "Доступные разделы:"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL | grep -v "loop"
    
    # Запрос корневого раздела
    read -p "Введите корневой раздел (например, /dev/sda2): " ROOT_PART
    check_device "$ROOT_PART"
    
    # Монтирование корневого раздела
    print_message "Монтирование корневого раздела $ROOT_PART в /mnt..."
    mount "$ROOT_PART" /mnt
    
    # Проверка и монтирование EFI раздела (если существует)
    if [ -d /sys/firmware/efi ]; then
        print_message "Обнаружена UEFI система, поиск EFI раздела..."
        
        # Поиск EFI раздела
        EFI_PART=$(lsblk -o NAME,MOUNTPOINT | grep -E '/mnt/boot/efi|/mnt/boot' | head -1 | awk '{print "/dev/"$1}')
        
        if [ -z "$EFI_PART" ]; then
            print_message "EFI раздел не смонтирован автоматически, попытка найти вручную..."
            lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL | grep -E 'EFI|esp|fat'
            read -p "Введите EFI раздел (например, /dev/sda1) или нажмите Enter чтобы пропустить: " EFI_PART
            
            if [ -n "$EFI_PART" ]; then
                check_device "$EFI_PART"
                mkdir -p /mnt/boot/efi
                mount "$EFI_PART" /mnt/boot/efi
            fi
        fi
    fi
    
    # Монтирование виртуальных файловых систем
    print_message "Монтирование виртуальных файловых систем..."
    mount -t proc /proc /mnt/proc
    mount -t sysfs /sys /mnt/sys
    mount -o bind /dev /mnt/dev
    mount -o bind /dev/pts /mnt/dev/pts
    mount -o bind /run /mnt/run
    
    # Переход в chroot
    print_message "Переход в chroot окружение..."
    if command -v artix-chroot >/dev/null 2>&1; then
        artix-chroot /mnt
    else
        chroot /mnt
    fi
    
    # После выхода из chroot
    print_message "Выход из chroot окружения"
    
    # Размонтирование
    read -p "Размонтировать файловые системы? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_message "Размонтирование файловых систем..."
        umount -R /mnt
    fi
}

# Функция для установки системы
install_system() {
    print_message "Запуск установки QuasarLinux..."
    bash ~/QuasarLinux/INSTALLING.sh
}

# Запуск основной функции
if [ "$(id -u)" -ne 0 ]; then
    print_error "Этот скрипт должен быть запущен с правами root!"
    exit 1
fi
