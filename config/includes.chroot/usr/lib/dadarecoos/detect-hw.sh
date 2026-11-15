#!/bin/sh
# Roda no boot do live, antes do Calamares. Se houver tela de toque, deixa a
# caixa "tela sensível ao toque" já marcada no instalador (o usuário pode mudar).
mkdir -p /run/dadarecoos
touch=0
# ponytail: confia no ID_INPUT_TOUCHSCREEN do udev. Se o aparelho não reportar, o usuário marca à mão.
if udevadm info --export-db 2>/dev/null | grep -q 'ID_INPUT_TOUCHSCREEN=1'; then
	touch=1
fi
echo "TOUCH=$touch" > /run/dadarecoos/hw.env

conf=/etc/calamares/modules/packagechooser@extras.conf
if [ "$touch" = 1 ]; then
	sed -i 's/^default: .*/default: touch/' "$conf"
else
	sed -i 's/^default: .*/default: ""/' "$conf"
fi
