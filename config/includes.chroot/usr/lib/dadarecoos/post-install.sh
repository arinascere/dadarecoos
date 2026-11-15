#!/bin/bash
# Roda DENTRO do sistema recém-instalado (Calamares shellprocess@post), depois dos pacotes
# escolhidos. Aplica regras por hardware e por escolha do usuário. Cada regra é independente:
# se uma falha, a instalação continua e o erro vai para o log.
set -u
LOG=/var/log/dadarecoos-install.log
exec >>"$LOG" 2>&1
echo "== post-install $(date -Is)"

inst() { DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" || echo "FALHOU: $*"; }
has()  { dpkg -s "$1" >/dev/null 2>&1; }
warn() { echo "AVISO: $*"; }

# 0. Fontes do apt já foram preparadas por prepare-apt.sh (shellprocess@pre)
apt-get update || warn "apt update falhou"

# 1. Remove o que só servia para o instalador live
DEBIAN_FRONTEND=noninteractive apt-get purge -y calamares cage live-boot live-config || true
systemctl disable dadareco-installer.service || true
rm -f /etc/systemd/system/dadareco-installer.service /etc/systemd/system/getty@tty1.service

# 2. CPU: microcode
if grep -qi GenuineIntel /proc/cpuinfo; then inst intel-microcode; fi
if grep -qi AuthenticAMD /proc/cpuinfo; then inst amd64-microcode; fi

# 3. GPU
gpu=$(lspci -nn | grep -Ei 'vga|3d|display')
if grep -qi intel <<<"$gpu"; then inst vainfo i965-va-driver intel-media-va-driver-non-free; fi
if grep -Eqi 'amd|ati' <<<"$gpu"; then inst mesa-va-drivers mesa-vulkan-drivers; fi
if grep -qi nvidia <<<"$gpu"; then
	# Secure Boot bloqueia módulo sem assinatura. Só instala com ele desligado.
	if mokutil --sb-state 2>/dev/null | grep -qi disabled; then inst nvidia-driver
	else warn "NVIDIA detectada com Secure Boot ligado: driver proprietário NÃO instalado (usa nouveau)."; fi
fi

# 4. Wi-Fi Broadcom proprietário (DKMS)
if lspci -nn | grep -Ei 'network' | grep -qi broadcom; then inst broadcom-sta-dkms linux-headers-amd64; fi

# 5. Notebook: energia
if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then inst tlp; fi

# 6. Pouca RAM (<= 4 GB): zram
mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [ "$mem_mb" -le 4200 ]; then
	inst zram-tools
	printf 'ALGO=zstd\nPERCENT=50\n' > /etc/default/zramswap
fi

# 7. Homelab: tampa fechada não suspende
if has samba; then
	mkdir -p /etc/systemd/logind.conf.d
	printf '[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\n' \
		> /etc/systemd/logind.conf.d/dadareco-homelab.conf
fi
# ponytail: Jellyfin fora da v1. Não está no Debian; precisa do repositório oficial deles (URL/chave a confirmar).

# 8. Touchscreen (marcado no instalador => iio-sensor-proxy foi instalado)
if has iio-sensor-proxy; then
	echo "touch: ligado"
	# KDE Plasma: teclado Maliit na sessão Wayland
	# ponytail: chave do kwinrc a confirmar em teste real.
	if has plasma-desktop; then
		install -d /etc/xdg
		printf '[Wayland]\nInputMethod=/usr/share/applications/com.github.maliit.keyboard.desktop\n' >> /etc/xdg/kwinrc
	fi
	# niri: teclado ligado/desligado pelo modo tablet + rotação via sensor
	if has niri; then
		install -m 0755 /usr/lib/dadarecoos/auto-rotate.sh /usr/local/bin/dadareco-auto-rotate
		cfg=""
		for c in /usr/share/doc/niri/default-config.kdl /usr/share/niri/default-config.kdl; do
			[ -f "$c" ] && cfg=$c && break
		done
		if [ -n "$cfg" ]; then
			install -d /etc/skel/.config/niri
			cp "$cfg" /etc/skel/.config/niri/config.kdl
			cat /usr/share/dadarecoos/niri-touch.kdl >> /etc/skel/.config/niri/config.kdl
		else
			warn "default-config.kdl do niri não encontrado: toque do niri NÃO configurado. Ver /usr/share/dadarecoos/niri-touch.kdl"
		fi
	fi
fi

# 9. Noctalia (shell do niri): só se o pacote estiver disponível no apt
if has niri; then
	if apt-cache policy noctalia-shell 2>/dev/null | grep -q 'Candidate: [0-9]'; then
		inst noctalia-shell
	else
		warn "noctalia-shell indisponível no apt. Niri instalado sem shell. Repositório a confirmar (ver README)."
		cp /usr/share/dadarecoos/NOCTALIA-PENDENTE.txt /etc/skel/NOCTALIA-PENDENTE.txt 2>/dev/null || true
	fi
fi

echo "== fim"
exit 0
