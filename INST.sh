echo "=========================================="
echo "    QUASAR LINUX ALPHA - ПОСТ-УСТАНОВКА"
echo "=========================================="
echo ""
echo "Добро пожаловать в Quasar Linux!"
echo "Этот скрипт установит и настроит:"
echo "Несколько раз вам может предложить вести пароль"
echo "- KDE Plasma Desktop Environment"
echo "- SDDM Display Manager"
echo "- Дополнительные приложения"
echo "- Настройки системы"
read -p "Начать установку? GO?  (y/N): " start_install
if [[ ! "$start_install" =~ ^[Yy]$ ]]; then
    echo "Отмена установки"
    exit 0
fi



echo "установка Plasma"
sudo pacman -Syy


sudo pacman -S --noconfirm plasma seatd go sddm sddm-openrc dolphin qt6 wine-staging winetricks qt6-tools qt5-tools kcalc gwenview kate vlc konsole mesa vulkan-tools gamemode lib32-gamemode lib32-alsa-plugins  lib32-libpulse pipewire gst-plugins-base gst-plugins-good  gst-plugins-bad  gst-plugins-ugly pavucontrol flatpak 
sleep 5

sudo rc-update add seatd default


cat >> ~/.bash_profile << 'EOF'
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi
EOF
clear

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo


clear
sleep 5
echo "Настройка Wine"
wineboot --init

sleep 2



winetricks --force -q --unattended corefonts tahoma cjkfonts vcrun6 vcrun2003 vcrun2005 vcrun2008 vcrun2010 vcrun2012 vcrun2013 vcrun2015 vcrun2019 vcrun2022 dotnet20 dotnet30 dotnet35 dotnet40 dotnet45 dotnet462 dotnet48 dotnetcoredesktop3 dotnetcoredesktop6 d3dcompiler_43 d3dcompiler_47 d3dx9 d3dx10 d3dx11_43 directx9 directx10 directx11 xact xinput quartz devenum wmp9 wmp10 wmp11 msxml3 msxml4 msxml6 gdiplus riched20 riched30 vb6run mfc40 mfc42 mfc70 mfc80 mfc90 mfc100 mfc110 mfc140 ie8 flash silverlight physx openal dsound xna40 faudio dxvk vkd3d dgvoodoo2 win10

sleep 3
clear

git clone https://aur.archlinux.org/yay-bin
cd yay-bin
makepkg -si --noconfirm
clear
echo "Активировация   Waydroid"
read -p "Начать установку Waydroid? (y/N): " waydroid
if [[ "$waydroid" =~ ^[Yy]$ ]]; then
    yay -S waydroid --noconfirm
    waydroid init

    mkdir -p /etc/sv/waydroid

    cat << 'EOF' > /etc/sv/waydroid/run
#!/bin/sh
exec 2>&1
exec waydroid container start
EOF

    chmod +x /etc/sv/waydroid/run

    ln -sf /etc/sv/waydroid /etc/runit/runsvdir/default/

    sv start waydroid
fi
clear

echo "Настройка SDDM..."
sudo groupadd -f sddm
sudo useradd -r -g sddm -s /usr/bin/nologin -d /var/lib/sddm sddm 2>/dev/null || true
sudo mkdir -p /var/lib/sddm /var/run/sddm
sudo chown sddm:sddm /var/lib/sddm /var/run/sddm
sudo chmod 0755 /var/lib/sddm /var/run/sddm
sudo usermod -aG seat,video,input sddm





# Настройка SDDM конфига
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/quasar.conf << 'SDDM_CONF_EOF'
[General]
HaltCommand=/usr/bin/eloginctl poweroff
RebootCommand=/usr/bin/eloginctl reboot

[X11]
SessionDir=/usr/share/xsessions
XauthPath=/usr/bin/xauth

[Wayland]
SessionDir=/usr/share/wayland-sessions
EnableHiDPI=true
SDDM_CONF_EOF

# Активация SDDM
echo "Активация SDDM..."
sudo ln -s /etc/sv/sddm /etc/runit/runsvdir/default/
sudo usermod -aG elogind $(whoami)
clear
echo "Настройка звука..."
sudo pacman -Rdd --noconfirm jack2  

sleep 5

sudo pacman -S --noconfirm  --overwrite '*' --needed pipewire lib32-libpipewire libpipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pipewire-audio pipewire-runit pipewire-pulse-runit lib32-pipewire-jack
sleep 5

clear

sleep 2

sudo chmod +x /etc/init.d/pipewire
sudo ln -s /etc/sv/pipewire /etc/runit/runsvdir/default/

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


sudo ln -s /etc/sv/elogind /etc/runit/runsvdir/default/
sudo ln -s /etc/sv/pipewire-pulse /etc/runit/runsvdir/default/

sudo pacman -S --noconfirm polkit polkit-qt6 polkit-kde-agent



elogind_conf="/etc/elogind/logind.conf"
add_or_replace_conf_param() {
    local key="$1"
    local value="$2"
    if grep -q "^$key=" "$elogind_conf"; then
        sudo sed -i "s|^$key=.*|$key=$value|" "$elogind_conf"
    else
        echo "$key=$value" | sudo tee -a "$elogind_conf" > /dev/null
    fi
}

add_or_replace_conf_param "HandlePowerKey" "poweroff"
add_or_replace_conf_param "HandleSuspendKey" "suspend"
add_or_replace_conf_param "HandleHibernateKey" "hibernate"
add_or_replace_conf_param "HandleLidSwitch" "suspend"



sudo chmod +x /etc/local.d/fixing.start
sudo ln -s /etc/sv/local /etc/runit/runsvdir/default/
sudo pacman -Scc --noconfirm
clear

echo "Установка завершена! Перезагрузка через 10 секунд..."
sleep 10
reboot


