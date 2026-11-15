#!/bin/sh
# Roda dentro do cage. 1) garante internet, 2) abre o Calamares.
# ponytail: tela de Wi-Fi = nmtui num terminal (precisa de teclado físico). Tela própria de toque na v2.

[ -r /run/dadarecoos/hw.env ] && . /run/dadarecoos/hw.env
# Teclado virtual do Qt dentro do instalador quando há tela de toque.
[ "${TOUCH:-0}" = 1 ] && export QT_IM_MODULE=qtvirtualkeyboard

until nm-online -q -t 8; do
	foot -e sh -c '
		echo "DadarecoOS precisa de internet para instalar."
		echo
		echo " - Cabo de rede: conecta sozinho, aguarde alguns segundos."
		echo " - Wi-Fi: escolha \"Ativar uma conexão\" na próxima tela."
		echo " - Sem driver de Wi-Fi? Ligue o celular por USB e ative o tethering."
		echo
		printf "Enter para abrir o gerenciador de rede... "
		read _
		nmtui
	'
done

exec calamares
