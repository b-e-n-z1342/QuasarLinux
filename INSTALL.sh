#!/bin/bash

for i in {1..6}; do
    sudo openvt -c $i -s -- setfont ter-v16n
done

read -p "у вас WIFI ?  (y/N): " iwifi
if [[ ! "$iwifi" =~ ^[Yy]$ ]]; then 
	echo "ok"
	./INST.sh
	exit 0
fi


echo "Давайте сперва подключимся к интернету через iwd"
echo "Это не страшно! "

echo "сейчас вы видите какие у вас сетевые карты"

echo "выберите какую вы будете использовать (ничего вводить не надо)"
echo "после выбора напишите"

echo "station <интерфейс> scan"
echo "после этого" 

echo "station <интерфейс> get-networks "

echo "далее"


echo "station <> connect <название вашей сети wifi>"
echo "после этого ведёте пароль и закройте её командой: exit"
iwctl device list 
iwctl

./INST.sh
