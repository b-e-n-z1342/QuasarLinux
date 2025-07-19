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

WINEDLLOVERRIDES="mscoree,mshtml=" WINEARCH=win64 winetricks --unattended --force -q mono gecko corefonts tahoma cjkfonts vcrun6 vcrun2003 vcrun2005 vcrun2008 vcrun2010 vcrun2012 vcrun2013 vcrun2015 vcrun2019 vcrun2022 dotnet20 dotnet30 dotnet35 dotnet40 dotnet45 dotnet462 dotnet48 dotnetcoredesktop3 dotnetcoredesktop6 d3dcompiler_43 d3dcompiler_47 d3dx9 d3dx10 d3dx11_43 directx9 directx10 directx11 xact xinput quartz devenum wmp9 wmp10 wmp11 msxml3 msxml4 msxml6 gdiplus riched20 riched30 vb6run mfc40 mfc42 mfc70 mfc80 mfc90 mfc100 mfc110 mfc140 ie8 flash silverlight physx openal dsound xna40 faudio dxvk vkd3d dgvoodoo2 win10 >/dev/null 2>&1

winetricks win10



