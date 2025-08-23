echo "=========================================="
echo "    QUASAR LINUX BETA - ПОСТ-УСТАНОВКА"
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
#сновные пакеты 
sudo pacman -Syy
sudo pacman -S wayland seatd lib32-gamemode lib32-alsa-plugins go lib32-libpulse pipewire gst-plugins-base gst-plugins-good  gst-plugins-bad  gst-plugins-ugly pavucontrol flatpak gvfs gvfs-mtp gvfs-smb polkit
# установка DE
function hypr() {
    sudo pacman -S hyprland waybar rofi kitty ly 
    sudo rc-update add ly default
}
function plasma() {
    sudo pacman -S plasma konsole dolphin kate gwenview sddm sddm-openrc kcalc vlc qt6 qt5
    sleep 1
    sudo pacman -Rns discover
    
    echo "Настройка SDDM..."
    sudo groupadd -f sddm
    sudo useradd -r -g sddm -s /usr/bin/nologin -d /var/lib/sddm sddm 2>/dev/null || true
    sudo mkdir -p /var/lib/sddm /var/run/sddm
    sudo chown sddm:sddm /var/lib/sddm /var/run/sddm
    sudo chmod 0755 /var/lib/sddm /var/run/sddm
    sudo usermod -aG seat,video,input sddm
    sudo pacman -S --noconfirm plasma-localization-ru kde-l10n-ru
    sudo rc-update sddm default
}
function mous() {
    sudo pacman -S  xfce4 xfce4-goodies thunar thunar-archive-plugin thunder-media-tags-plagin lightdm lightdm-openrc lightdm-gtk-greeter lightdm-gtk-greeter-settings
    systemctl enable lightdm
}
echo "Выберите DE/WM"
echo "1) hyprland"
echo "2) KDE plasma"
echo "3) xfce4"
read -p "введите номер (1-3): " de
case $de in
    1) hypr ;;
    2) plasma ;;
    3) mous ;;
    *) echo "неверный выбор" ;;
exac
echo "поставить QT/GTK?"
read -p "GO? [Y/n]: " qt
if [[ ! "$qt" =~ ^[Yy]$ ]]; then
    sudo pacman -S --noconfirm  qt6 qt5 gtk2 gtk3 gtk4
    sleep 2
fi
sudo rc-update add seatd default


cat >> ~/.bash_profile << 'EOF'
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi
EOF
clear
flatpak install flathub -y
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

printf '=%.0s' $(seq 1 $COLUMNS)
echo "Настройка Wine"
echo "Wine -- не эмулятор, а альтернативная реализация Windows API, для виртуальных машин его установка излишня"
read -p "Начать установку Wine?  (y/N): " wine      
if [[ "$wine" =~ ^[Yy]$ ]]; then
    sudo pacman -S wine-staging winetricks wine-gecko gamemode --noconfirm
    wineboot --init
    sleep 2
    clear
    winetricks --force -q --unattended corefonts tahoma cjkfonts vcrun6 vcrun2003 vcrun2005 vcrun2008 vcrun2010 vcrun2012 vcrun2013 vcrun2015 vcrun2019 vcrun2022 dotnet20 dotnet30 dotnet35 dotnet40 dotnet45 dotnet462 dotnet48 dotnetcoredesktop3 dotnetcoredesktop6 d3dcompiler_43 d3dcompiler_47 d3dx9 d3dx10 d3dx11_43 directx9 directx10 directx11 xact xinput quartz devenum wmp9 wmp10 wmp11 msxml3 msxml4 msxml6 gdiplus riched20 riched30 vb6run mfc40 mfc42 mfc70 mfc80 mfc90 mfc100 mfc110 mfc140 ie8 flash silverlight physx openal dsound xna40 faudio dxvk vkd3d dgvoodoo2 win10
    sleep 5
    clear
fi

git clone https://aur.archlinux.org/yay-bin
cd yay-bin
makepkg -si --noconfirm
clear
echo "Активировация   Waydroid"
echo "Waydroid позволяет запускать android приложения в QuasarLinux"
read -p "Начать установку Waydroid? (y/N): " waydroid
if [[ "$waydroid" =~ ^[Yy]$ ]]; then
    sudo pacman -S python --noconfirm
    yay -S waydroid --noconfirm
    waydroid init
    sudo cat << 'EOF' > /etc/init.d/waydroid
#!/sbin/openrc-run
# Waydroid 

description="Запуск Waydroid-контейнера"
command=/usr/bin/waydroid
command_args="container start"
pidfile=/run/waydroid.pid
command_background=false

depend() {
    need localmount
    use net
}
EOF
    sudo chmod +x /etc/init.d/waydroid
    sudo rc-update add waydroid default
fi
clear

# Активация 
sudo usermod -aG elogind $(whoami)
clear
printf '=%.0s' $(seq 1 $COLUMNS)
echo "Настройка звука..."
sudo pacman -Rdd --noconfirm jack2  
sleep 1
sudo pacman -S --noconfirm  --overwrite '*' --needed pipewire lib32-libpipewire libpipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pipewire-audio pipewire-openrc pipewire-pulse-openrc lib32-pipewire-jack
sleep 5

clear

sleep 2

sudo chmod +x /etc/init.d/pipewire
sudo rc-update add pipewire default

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


sudo rc-update add elogind default
sudo rc-update add pipewire-pulse default

sudo pacman -S --noconfirm polkit polkit-qt6 polkit-kde-agent


sudo cat << 'EOF' > /etc/os-release
NAME="QuasarLinux"
VERSION="0.2-BETA"
PRETTY_NAME="Quasar Linux (Artix base)"
ID=QuasarLinux
ID_LIKE=artix
ANSI_COLOR="0;36"
HOME_URL="https://b-e-n-z1342.github.io"
EOF
sudo rm /etc/artix-release
sudo cat > /etc/quasar-release << EOF

EOF
        
sudo cat > /etc/lsb-release << 'LSB_EOF'
DISTRIB_ID=Quasar
DISTRIB_RELEASE=0.3
DISTRIB_DESCRIPTION="Quasar Linux"
DISTRIB_CODENAME=rolling
LSB_EOF

printf '=%.0s' $(seq 1 $COLUMNS)
sudo chmod +x /etc/local.d/fixing.start
sudo rc-update add local default
clear 
sleep 2
printf '=%.0s' $(seq 1 $COLUMNS)
echo "Чистка кэша"
sudo pacman -Scc --noconfirm
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

clear
printf '=%.0s' $(seq 1 $COLUMNS)
echo "Установка завершена! Перезагрузка через 5 секунд..."
sleep 5
sudo reboot


