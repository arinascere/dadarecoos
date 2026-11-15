#!/bin/bash
# Roda no boot do live, antes do Calamares. Detecta touchscreen e gera a tela
# "Extras" do instalador com a caixa de touch já marcada (o usuário pode mudar).
set -u

mkdir -p /run/dadarecoos
touch=0
# ponytail: só ID_INPUT_TOUCHSCREEN do udev. Se algum aparelho não reportar, a caixa fica desmarcada e o usuário marca à mão.
if udevadm info --export-db 2>/dev/null | grep -q 'ID_INPUT_TOUCHSCREEN=1'; then
	touch=1
fi
echo "TOUCH=$touch" > /run/dadarecoos/hw.env

default='[ ]'
[ "$touch" = 1 ] && default='[ touch ]'

cat > /etc/calamares/modules/packagechooser@extras.conf <<EOF
# Gerado por detect-hw.sh a cada boot. NÃO editar aqui; editar o script.
mode: optional
method: packages
labelDefault: Extras
default: $default
items:
  - id: touch
    name: "Dispositivo com tela sensível ao toque"
    description: "Teclado virtual, rotação automática e interface adaptada para toque."
    packages: [ iio-sensor-proxy, maliit-keyboard, wvkbd, jq ]
  - id: games
    name: "Jogos (Steam)"
    description: "Steam e drivers de vídeo 32 bits."
    packages: [ steam-installer ]
  - id: homelab
    name: "Homelab / NAS"
    description: "Samba, descoberta na rede e monitoramento de disco. Tampa fechada não suspende."
    packages: [ samba, avahi-daemon, smartmontools ]
EOF
