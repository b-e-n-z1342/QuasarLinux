#!/bin/bash
setfont ter-v20n
clear
printf '=%.0s' $(seq 1 $COLUMNS)
# Функция для настройки DNS
configure_dns() {
    echo "Выберите DNS сервер:"
    echo "1) Cloudflare (1.1.1.1, 1.0.0.1)   -- скорость"
    echo "2) Google (8.8.8.8, 8.8.4.4)    --скорость"
    echo "3) Quad9 (9.9.9.9, 149.112.112.112)    --стабильность"
    echo "4) OpenDNS (208.67.222.222, 208.67.220.220)"
    echo "5) Не менять DNS (оставить как есть)"
    read -p "Ваш выбор [1-5]: " dns_choice

    case $dns_choice in
        1)
            dns_servers="1.1.1.1 1.0.0.1"
            ;;
        2)
            dns_servers="8.8.8.8 8.8.4.4"
            ;;
        3)
            dns_servers="9.9.9.9 149.112.112.112"
            ;;
        4)
            dns_servers="208.67.222.222 208.67.220.220"
            ;;
        5)
            echo "DNS не изменены"
            return 0
            ;;
        *)
            echo "Неверный выбор, DNS не изменены"
            return 1
            ;;
    esac

    echo "Настраиваем DNS серверы: $dns_servers"
    sudo mkdir -p /etc/NetworkManager/conf.d/
    echo -e "[global]\ndns=none" | sudo tee /etc/NetworkManager/conf.d/dns.conf >/dev/null
    sudo rc-service NetworkManager restart

    # Проверяем, существует ли уже resolv.conf
    if [ -f /etc/resolv.conf ]; then
        sudo mv /etc/resolv.conf /etc/resolv.conf.backup
    fi

    for server in $dns_servers; do
        echo "nameserver $server" | sudo tee -a /etc/resolv.conf >/dev/null
    done

    echo "DNS успешно настроены!"
}

# Проверяем, есть ли Wi-Fi адаптер
check_wifi_available() {
    if nmcli device | grep -q wifi; then
        return 0
    else
        return 1
    fi
}

# Основная функция подключения к Wi-Fi
connect_to_wifi() {
    echo "Доступные Wi-Fi сети:"
    nmcli device wifi list
    
    read -p "Введите SSID сети: " ssid
    if [ -z "$ssid" ]; then
        echo "Ошибка: SSID не может быть пустым!"
        return 1
    fi
    
    read -sp "Введите пароль (оставьте пустым для открытой сети): " password
    echo
    
    if [ -z "$password" ]; then
        echo "Подключаемся к открытой сети $ssid..."
        if ! nmcli device wifi connect "$ssid"; then
            echo "Ошибка подключения к сети $ssid"
            return 1
        fi
    else
        echo "Подключаемся к защищенной сети $ssid..."
        if ! nmcli device wifi connect "$ssid" password "$password"; then
            echo "Ошибка подключения к сети $ssid (неверный пароль?)"
            return 1
        fi
    fi
    
    echo "Успешно подключено к $ssid!"
    
    # Предлагаем настроить DNS
    read -p "Хотите настроить DNS серверы? [y/N]: " configure_dns_choice
    if [[ "$configure_dns_choice" =~ ^[Yy]$ ]]; then
        configure_dns
    fi
    
    return 0
}

# Проверка интернет соединения
check_internet() {
    echo "Проверяем интернет соединение..."
    if ping -c 3 archlinux.org &> /dev/null; then
        echo "Интернет соединение активно!"
        return 0
    else
        echo "Нет интернет соединения!"
        return 1
    fi
}

# Главное меню
echo "=== Настройка сети ==="

# Проверяем, есть ли Wi-Fi адаптер
if check_wifi_available; then
    read -p "У вас есть Wi-Fi и вы хотите подключиться? [Y/n]: " wifi_choice
    if [[ "$wifi_choice" =~ ^[Nn]$ ]]; then
        echo "Пропускаем настройку Wi-Fi..."
    else
        connect_to_wifi
    fi
else
    echo "Wi-Fi адаптер не обнаружен, пропускаем настройку Wi-Fi..."
fi

# Проверка интернета в любом случае
if ! check_internet; then
    echo "Предупреждение: Интернет соединение отсутствует!"
    echo "Некоторые функции установки могут не работать без интернета."
    read -p "Продолжить без интернета? [y/N]: " no_internet_choice
    if [[ ! "$no_internet_choice" =~ ^[Yy]$ ]]; then
        echo "Прерывание выполнения скрипта..."
        exit 1
    fi
fi

echo "Переходим к основной установке..."
exec ./INST.sh
