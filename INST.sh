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
mkdir ~/.apps
#сновные пакеты 
sudo pacman -Syy
sudo pacman -S wayland seatd lib32-gamemode pipewire-jack polkit polkit-qt6 polkit-kde-agent lib32-alsa-plugins go lib32-libpulse gst-plugins-base gst-plugins-good   --noconfirm
sudo pacman -S gst-plugins-bad  gst-plugins-ugly pavucontrol flatpak gvfs gvfs-mtp gvfs-smb polkit x264 x265 openh264 gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav ffmpeg  --noconfirm

git clone https://aur.archlinux.org/yay-bin
cd yay-bin
makepkg -si --noconfirm
# установка DE
printf '=%.0s' $(seq 1 $(tput cols))
echo "Выберите DE или WM."
function hypr() {
    sudo pacman -S hyprland waybar rofi kitty ly ly-openrc hyprland-protocols hyprgraphics hypridle hyprcursor hyprland-qt-support hyprutils xdg-desktop-portal-hyprland  --noconfirm
    
    sudo rc-update add ly default
}

function plasma() {
    sudo pacman -S plasma konsole dolphin kate gwenview sddm sddm-openrc kcalc vlc qt6 qt5 --noconfirm
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

function mouse() {
    sudo pacman -S  xfce4 xfce4-goodies thunar thunar-archive-plugin thunder-media-tags-plagin lightdm lightdm-openrc lightdm-gtk-greeter lightdm-gtk-greeter-settings  --noconfirm
    sudo rc-update add  lightdm default
}

function gnome() {
    sudo pacman -S gnome gdm gdm-openrc  --noconfirm
    sudo rc-update add  gdm default
}
function non() {
    echo "OK"
}
echo "Выберите DE/WM"
echo "1) hyprland"
echo "2) KDE plasma"
echo "3) xfce4"
echo "4) Gnome"
echo "5) без DE/WM"
read -p "введите номер (1-5): " de
case $de in
    1) hypr ;;
    2) plasma ;;
    3) mouse ;;
    4) non ;;
    5) gnome ;;
    *) echo "неверный выбор" ;;
esac
clear
printf '=%.0s' $(seq 1 $(tput cols))
read -p "Вы хотите установить QT/GTK? (Y/n): " answer
case ${answer:0:1} in
    y|Y|"")
        sudo pacman -Sy
        sudo pacman -S qt6 qt5 gtk2 gtk3 gtk4 --noconfirm
    ;;
    *)
        echo "OK"    
    ;;
esac
sudo rc-update add seatd default


cat >> ~/.bash_profile << 'EOF'
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi
EOF
clear

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub -y
printf '=%.0s' $(seq 1 $(tput cols))
echo "Настройка Wine"
echo "Wine -- это не эмулятор, а альтернативная реализация Windows API, для виртуальных машин его установка излишня"
echo "но у него есть куча версий! какую ставить ?"

function wine() {
    sudo pacman -S wine wine-gecko winetricks  --noconfirm
}

function staging() {
    sudo pacman -S wine-staging wine-gecko winetricks  --noconfirm
}

function quasar() {
    sudo pacman -S wine-staging winetricks wine-gecko gamemode --noconfirm
    wineboot --init
    sleep 2
    clear
    winetricks --force -q --unattended corefonts tahoma cjkfonts vcrun6 vcrun2003 vcrun2005 vcrun2008 vcrun2010 vcrun2012 vcrun2013 vcrun2015 vcrun2019 vcrun2022 dotnet20 dotnet30 dotnet35 dotnet40 dotnet45 dotnet462 dotnet48 dotnetcoredesktop3 dotnetcoredesktop6 d3dcompiler_43 
    winetricks --force -q --unattended d3dcompiler_47 d3dx9 d3dx10 d3dx11_43 directx9 directx10 directx11 xact xinput quartz devenum wmp9 wmp10 wmp11 msxml3 msxml4 msxml6 gdiplus riched20
    winetricks --force -q --unattended riched30 vb6run mfc40 mfc42 mfc70 mfc80 mfc90 mfc100 mfc110 mfc140 ie8 flash silverlight physx openal dsound xna40 faudio dxvk vkd3d dgvoodoo2 win10
    sleep 5
    clear
}

function ge() {
    wget -P /tmp https://github.com/GloriousEggroll/wine-ge-custom/releases/download/GE-Proton8-26/wine-lutris-GE-Proton8-26-x86_64.tar.xz
    sleep 1
    tar -xf /tmp/wine-lutris-GE-Proton8-26-x86_64.tar.xz -C ~/.apps
    sleep 1
    cd ~/.apps
    mv lutris-GE-Proton8-26-x86_64 wine-ge
    sudo ln -sf wine-ge/bin/* /usr/local/bin
    sudo ln -sf wine-ge/lib/wine /usr/local/lib/wine
    sudo ln -sf wine-ge/share/* /usr/local/share
    sleep 1 
    wineboot --init
}

function proton() {
    wget -P /tmp https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-13/GE-Proton10-13.tar.gz
    tar -xf /tmp/GE-Proton10-13.tar.gz -C ~/.apps
    mv GE-Proton10-13 proton-ge
    sudo ln -sf proton-ge/files/bin/* /usr/local/bin
    sudo ln -sf proton-ge/files/share/* /usr/local/share
}
function port() {
    yay -S protoroton
}

function no() {
    echo "OK"
}
echo "Выберите вариант:"
echo "1) обычный wine"
echo "2) wine-staging"
echo "3) wine-staging настроенный для QuasarLinux"
echo "4) wine-ge"
echo "5) proton-ge"
echo "6) PortProton --рекомендуется новичкам"
echo "7) без wine"
read -p "Введите номер (1-6): " choice

case $choice in
    1) wine ;;
    2) staging ;;
    3) quasar ;;
    4) ge ;;
    5) proton ;;
    6) no ;;
    *) echo "Неверный выбор" ;;
esac
clear

printf '=%.0s' $(seq 1 $(tput cols))
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
printf '=%.0s' $(seq 1 $(tput cols))
echo "QuasarLinux имеет фишку которая является основной!"
echo "это -- блокировка телеметрии"
echo "около 60-80% системы без телеметрии, к релизу будет 90-99%"
echo "блокировка тронет только системные компаненты QuasarLinux {wine, DE, браузер и тд}"

sleep 7

sudo tee /etc/host << 'EOF'
0.0.0.0 vortex.data.microsoft.com
0.0.0.0 settings-win.data.microsoft.com
0.0.0.0 telemetry.microsoft.com
0.0.0.0 watson.telemetry.microsoft.com
0.0.0.0 clients2.google.com
0.0.0.0 clients4.google.com
0.0.0.0 update.googleapis.com
0.0.0.0 dl.google.com
0.0.0.0 incoming.telemetry.mozilla.org
0.0.0.0 detectportal.firefox.com
0.0.0.0 location.services.mozilla.com
0.0.0.0 shavar.services.mozilla.com
0.0.0.0 telemetry.winehq.org
0.0.0.0 cdn.winehq.org
0.0.0.0 staging.winehq.org
0.0.0.0 telemetry.yandex.ru
0.0.0.0 clck.yandex.ru
0.0.0.0 yabs.yandex.ru
0.0.0.0 mc.yandex.ru
0.0.0.0 dsp.yandex.ru
EOF
echo "блокитровка завершена! все эти домены можно востановить если поставить перед ними : # : всё заблокированное находится в /etc/host."





# Активация 
sudo usermod -aG elogind $(whoami)
clear
printf '=%.0s' $(seq 1 $(tput cols))
echo "Настройка звука..."
sudo pacman -Rdd --noconfirm jack2  
sleep 1
sudo pacman -S --noconfirm  --overwrite '*' --needed pipewire lib32-libpipewire libpipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pipewire-audio pipewire-openrc pipewire-pulse-openrc lib32-pipewire-jack
sleep 5

clear
printf '=%.0s' $(seq 1 $(tput cols))
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

printf '=%.0s' $(seq 1 $(tput cols))
sudo chmod +x /etc/local.d/fixing.start
sudo rc-update add local default
clear 
sleep 2
printf '=%.0s' $(seq 1 $(tput cols))
echo "Чистка кэша"
sudo pacman -Scc --noconfirm
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

sudo tee /etc/os-release << EOF
NAME="QuasarLinux"
VERSION="0.2-BETA"
PRETTY_NAME="Quasar Linux (Artix base)"
ID=QuasarLinux
ID_LIKE=artix
ANSI_COLOR="0;36"
HOME_URL="https://b-e-n-z1342.github.io"
EOF

clear
printf '=%.0s' $(seq 1 $(tput cols))
echo "установка подошла к концу, но остался один вопрос"
echo "какой браузер ставить?"
echo "!!! все браузеры будут установленны через flatpak с flathub !!!"

function option1() {
    flatpak install flathub org.mozilla.firefox
    cat /usr/local/bin/firefox << EOF
flatpak run org.mozilla.firefox
EOF

    
}

function option2() {
    flatpak install flathub org.chromium.Chromium
    cat /usr/local/bin/chromium << EOS
flatpak run org.chromium.Chromium
EOS
}

function option3() {
    flatpak install flathub com.brave.Browser
    cat /usr/local/bin/chromium << EOS
flatpak run org.chromium.Chromium
EOS
}
function option4() {
    flatpak install flathub io.github.ungoogled_software.ungoogled_chromium
        cat /usr/local/bin/chromium << EOS
flatpak run io.github.ungoogled_software.ungoogled_chromium
EOS
}

function option5() {
    flatpak install flathub io.gitlab.librewolf-community
        cat /usr/local/bin/librewolf-community<< EOS
flatpak run io.gitlab.librewolf-community
EOS
}

function option6() {
    flatpak install flathub com.github.micahflee.torbrowser-launcher
        cat /usr/local/bin/torbrowser-launcher << EOS
flatpak run org.torproject.torbrowser-launcher
EOS
}

function option7() {
    flatpak install flathub ru.yandex.Browser
        cat /usr/local/bin/Yandex.Browser << EOS
flatpak run ru.yandex.Browser
EOS
}

function option8() {
    flatpak install flathub org.kde.falkon
    cat /usr/local/bin/falkon << EOS
flatpak run org.kde.falkon
EOS
}

function option9() {
    echo "OK"
}

echo "Выберите вариант:"
echo "1) firefox    --open source"
echo "2) Chomium    -open source"
echo "2) brave    -open source"
echo "4) ungoogle-chroium    --open source"
echo "5) libre-wolf    --open source - анонимность"
echo "6) tor    - полная анонимность !! используте в благих целях !!     -open source"
echo "7) Yandex"
echo "8) falkon    --open source -легкий"
echo "9) без браузера"
read -p "Введите номер (1-9): " choice

case $choice in
    1) option1 ;;
    2) option2 ;;
    3) option3 ;;
    4) option4 ;;
    5) option5 ;;
    6) option6 ;;
    7) option7 ;;
    8) option8 ;;
    9) option9 ;;
    *) echo "Неверный выбор" ;;
esac


echo "Установка завершена! Перезагрузка через 5 секунд..."
sleep 5
sudo reboot


