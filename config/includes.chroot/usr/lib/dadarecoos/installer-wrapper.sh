#!/bin/sh
# Roda dentro do cage. 1) garante internet, 2) abre o Calamares.
# ponytail: tela de Wi-Fi = nmtui num terminal (precisa de teclado ou wvkbd). Trocar por tela QML própria na v2.

online() { nm-online -q -t 5; }

until online; do
	foot -e sh -c '
		echo "DadarecoOS: sem internet."
		echo "Cabo conecta sozinho. Para Wi-Fi: Activate a connection."
		echo "Sem driver de Wi-Fi? Use tethering USB do celular."
		echo
		read -p "Enter para abrir o gerenciador de rede..." _
		nmtui
	'
done

exec calamares
