#!/bin/bash
# Roda DENTRO do sistema recém-instalado, depois dos pacotes escolhidos e ANTES de
# criar o usuário (assim o /etc/skel já sai pronto). Aplica regras por hardware e
# por escolha feita no instalador.
#
# Cada regra é independente: se uma falha, a instalação continua e o motivo fica em
# /var/log/dadarecoos-install.log. A exceção é a limpeza do instalador (regra 1).
set -u
LOG=/var/log/dadarecoos-install.log
exec > >(tee -a "$LOG") 2>&1
echo "== post-install $(date -Is)"
export DEBIAN_FRONTEND=noninteractive

inst() { apt-get install -y --no-install-recommends "$@" || echo "FALHOU: instalar $*"; }
has()  { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed'; }
warn() { echo "AVISO: $*"; }
S=/usr/share/dadarecoos
WALL=/usr/share/backgrounds/dadarecoos/default.png

# Escolhas do instalador, lidas pelos pacotes que cada opção instala.
PLASMA=0; NIRI=0; TOUCH=0; GAMES=0; HOMELAB=0
has plasma-desktop  && PLASMA=1
has niri            && NIRI=1
has evtest          && TOUCH=1     # pacote-marcador da opção "tela sensível ao toque"
has steam-installer && GAMES=1
has samba           && HOMELAB=1

# Hardware
# DADARECO_MEM_MB: usado só pelo teste do CI para simular máquina fraca.
mem_mb=${DADARECO_MEM_MB:-$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)}
WEAK=0; [ "$mem_mb" -le 4200 ] && WEAK=1          # máquina fraca: 4 GB ou menos
gpu=$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' || true)
LAPTOP=0; ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && LAPTOP=1
echo "escolhas: plasma=$PLASMA niri=$NIRI touch=$TOUCH jogos=$GAMES homelab=$HOMELAB"
echo "hardware: ram=${mem_mb}MB fraca=$WEAK notebook=$LAPTOP gpu=[$gpu]"

# ---------------------------------------------------------------- 1. limpeza
# Tira o instalador do sistema final. Segurança: o serviço roda como root na tty1.
systemctl disable dadareco-installer.service 2>/dev/null || true
rm -f /etc/systemd/system/dadareco-installer.service \
      /etc/systemd/system/multi-user.target.wants/dadareco-installer.service
gone=()
[ "$NIRI" = 0 ] && has cage && gone+=(cage)      # no niri o cage hospeda a tela de login
for p in calamares calamares-settings-debian live-boot live-boot-initramfs-tools \
	live-config live-config-systemd live-tools; do
	has "$p" && gone+=("$p")
done
[ "${#gone[@]}" -gt 0 ] && { apt-get purge -y "${gone[@]}" || warn "limpeza do instalador incompleta"; }
rm -rf /etc/calamares

# ---------------------------------------------------------------- 2. CPU e GPU
grep -qi GenuineIntel /proc/cpuinfo && inst intel-microcode
grep -qi AuthenticAMD /proc/cpuinfo && inst amd64-microcode

if grep -qi intel <<<"$gpu"; then
	# i965 = Intel até Broadwell (o Bay Trail do HP x360); iHD = Broadwell em diante.
	inst i965-va-driver intel-media-va-driver-non-free
fi
grep -Eqi 'amd|ati|radeon' <<<"$gpu" && inst mesa-va-drivers
if grep -qi nvidia <<<"$gpu"; then
	# Secure Boot recusa módulo sem assinatura; só instala o driver com ele desligado.
	if mokutil --sb-state 2>/dev/null | grep -qi disabled || [ ! -d /sys/firmware/efi ]; then
		inst linux-headers-amd64 nvidia-driver
	else
		warn "NVIDIA com Secure Boot ligado: driver proprietário NÃO instalado (fica o nouveau)."
	fi
fi

# Wi-Fi Broadcom sem driver livre no kernel (BCM4331, 43142, 4352, 4360): só o
# proprietário funciona, e ele compila via DKMS. Os outros Broadcom já funcionam com o firmware da ISO.
# ponytail: lista de IDs curta e de memória; ampliar conforme aparecerem máquinas.
if lspci -nn 2>/dev/null | grep -Eqi '14e4:(4331|4365|43a0|43b1)'; then
	inst linux-headers-amd64 broadcom-sta-dkms
fi

# ---------------------------------------------------------------- 3. memória e disco
if [ "$WEAK" = 1 ]; then
	printf 'ALGO=zstd\nPERCENT=60\nPRIORITY=100\n' > /etc/default/zramswap
	printf 'vm.swappiness=100\nvm.page-cluster=0\n' > /etc/sysctl.d/60-dadareco-zram.conf
else
	printf 'ALGO=zstd\nPERCENT=25\nPRIORITY=100\n' > /etc/default/zramswap
fi

# ---------------------------------------------------------------- 4. vídeo no navegador
# Sem decodificação VP9 por hardware (caso do Celeron N2830), o YouTube em VP9/AV1
# vai para a CPU e engasga. Desligando VP9/AV1 o YouTube entrega H.264, que a GPU decodifica.
vp9=0
for d in /dev/dri/renderD*; do
	[ -e "$d" ] && vainfo --display drm --device "$d" 2>/dev/null | grep -q 'VP9' && vp9=1
done
install -d /etc/firefox-esr/policies /etc/firefox/policies
{
	echo '{ "policies": { "Preferences": {'
	echo '  "media.ffmpeg.vaapi.enabled": { "Value": true, "Status": "default" },'
	if [ "$vp9" = 0 ]; then
		echo '  "media.mediasource.vp9.enabled": { "Value": false, "Status": "default" },'
		echo '  "media.av1.enabled": { "Value": false, "Status": "default" },'
	fi
	echo '  "browser.uidensity": { "Value": '"$([ "$TOUCH" = 1 ] && echo 2 || echo 0)"', "Status": "default" }'
	echo '} } }'
} > /etc/firefox-esr/policies/policies.json
cp /etc/firefox-esr/policies/policies.json /etc/firefox/policies/policies.json
echo "vp9 por hardware=$vp9"

# ---------------------------------------------------------------- 5. KDE Plasma
if [ "$PLASMA" = 1 ]; then
	install -d /etc/xdg /etc/xdg/autostart /etc/sddm.conf.d
	cp "$S/plasma/kdeglobals" /etc/xdg/kdeglobals
	cp "$S/plasma/kwinrc" /etc/xdg/kwinrc
	cp "$S/plasma/firstrun.desktop" /etc/xdg/autostart/dadareco-plasma-firstrun.desktop

	kwin_login="kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1"
	if [ "$TOUCH" = 1 ]; then
		inst maliit-keyboard
		# ponytail: chaves do kwinrc escritas sem teste em hardware. Conferir em Ajustes > Teclado > Teclado virtual.
		printf '\n[Wayland]\nInputMethod[$e]=/usr/share/applications/com.github.maliit.keyboard.desktop\nVirtualKeyboardEnabled=true\n' >> /etc/xdg/kwinrc
		kwin_login="$kwin_login --inputmethod maliit-keyboard"
		# alvos maiores para o dedo
		sed -i 's/^var TOP_HEIGHT = .*/var TOP_HEIGHT = 36;/; s/^var DOCK_HEIGHT = .*/var DOCK_HEIGHT = 72;/' \
			/usr/share/plasma/look-and-feel/org.dadarecoos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
	fi
	if [ "$WEAK" = 1 ]; then
		# GPU e disco fracos: sem desfoque, animações curtas, sem indexador de arquivos.
		printf '\n[Plugins]\nblurEnabled=false\ncontrastEnabled=false\n' >> /etc/xdg/kwinrc
		printf '\n[KDE]\nAnimationDurationFactor=0.5\n' >> /etc/xdg/kdeglobals
		printf '[Basic Settings]\nIndexing-Enabled=false\n' > /etc/xdg/baloofilerc
	fi
	# Tela de login em Wayland (sem precisar do Xorg), com o nosso fundo.
	cat > /etc/sddm.conf.d/10-dadarecoos.conf <<EOF
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=$kwin_login

[Theme]
Current=breeze
EOF
	[ -d /usr/share/sddm/themes/breeze ] && printf '[General]\nbackground=%s\n' "$WALL" > /usr/share/sddm/themes/breeze/theme.conf.user
	systemctl enable sddm.service || warn "não consegui habilitar o sddm"
fi

# ---------------------------------------------------------------- 6. niri + Noctalia
if [ "$NIRI" = 1 ]; then
	install -d /etc/skel/.config/niri
	cp "$S/niri/config.kdl" /etc/skel/.config/niri/config.kdl
	if [ "$TOUCH" = 1 ]; then
		inst squeekboard jq
		install -m 0755 /usr/lib/dadarecoos/auto-rotate.sh /usr/local/bin/dadareco-auto-rotate
		cat "$S/niri/touch.kdl" >> /etc/skel/.config/niri/config.kdl
	fi
	# Tela de login: greetd + gtkgreet dentro do cage.
	# (O noctalia-greeter exige bibliotecas gráficas mais novas que as do Debian 13.)
	# ponytail: sem teclado virtual nesta tela; login no niri precisa de teclado físico.
	layout=$(. /etc/default/keyboard 2>/dev/null; echo "${XKBLAYOUT:-br}")
	install -d /etc/greetd
	echo "niri-session" > /etc/greetd/environments
	cat > /etc/greetd/gtkgreet.css <<EOF
window {
    background-image: url("file://$WALL");
    background-size: cover;
    background-position: center;
}
box#body {
    background-color: rgba(30, 30, 46, 0.88);
    border-radius: 18px;
    padding: 36px;
}
* { font-family: "Inter"; }
EOF
	cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 7

[default_session]
command = "env XKB_DEFAULT_LAYOUT=$layout cage -s -- gtkgreet -s /etc/greetd/gtkgreet.css"
user = "_greetd"
EOF
	systemctl enable greetd.service || warn "não consegui habilitar o greetd"
fi
# As duas opções instaladas ao mesmo tempo não acontecem (escolha única no instalador).

# ---------------------------------------------------------------- 7. toque
[ "$TOUCH" = 1 ] && systemctl enable iio-sensor-proxy.service 2>/dev/null

# ---------------------------------------------------------------- 8. jogos
if [ "$GAMES" = 0 ]; then
	# sem Steam, não há por que manter a arquitetura de 32 bits
	dpkg --remove-architecture i386 2>/dev/null || true
fi

# ---------------------------------------------------------------- 9. homelab / NAS
if [ "$HOMELAB" = 1 ]; then
	# Notebook como servidor: fechar a tampa não suspende.
	install -d /etc/systemd/logind.conf.d
	printf '[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\nHandleLidSwitchDocked=ignore\n' \
		> /etc/systemd/logind.conf.d/dadareco-homelab.conf

	# Pasta de mídia: quem está no grupo "users" (o seu usuário) grava; o Jellyfin lê.
	install -d -m 2775 -g users /srv/midia /srv/midia/series /srv/midia/filmes
	cat > /srv/midia/LEIA-ME.txt <<'EOF'
Coloque suas séries em /srv/midia/series e filmes em /srv/midia/filmes.

Jellyfin: abra http://IP-DESTE-COMPUTADOR:8096 em outro aparelho e siga o assistente.
Na TV Android, instale o app "Jellyfin" e aponte para esse mesmo endereço.
Neste computador fraco, prefira vídeos em H.264: assim a TV toca direto (direct
play) e o servidor não precisa converter.

Pasta de rede (Samba): defina uma senha com   sudo smbpasswd -a SEU_USUARIO
e acesse \\NOME-DO-COMPUTADOR\midia pela rede.
EOF
	if ! grep -q '^\[midia\]' /etc/samba/smb.conf 2>/dev/null; then
		cat >> /etc/samba/smb.conf <<'EOF'

[midia]
   comment = DadarecoOS: midia
   path = /srv/midia
   browseable = yes
   read only = no
   guest ok = no
   valid users = @users
   force group = users
   create mask = 0664
   directory mask = 2775
EOF
	fi
	if [ -e /etc/apt/sources.list.d/jellyfin.sources ]; then
		inst jellyfin
		has jellyfin && usermod -aG users jellyfin 2>/dev/null
	else
		warn "Jellyfin não instalado (repositório indisponível na instalação). Veja https://jellyfin.org/docs/"
	fi
	# Servidor ligado 24h: atualizações de segurança automáticas.
	printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > /etc/apt/apt.conf.d/20auto-upgrades
else
	rm -f /etc/apt/sources.list.d/jellyfin.sources /etc/apt/keyrings/jellyfin.asc
fi

# ---------------------------------------------------------------- 10. repositórios e serviços
if [ "$NIRI" = 0 ]; then
	rm -f /etc/apt/sources.list.d/noctalia-trixie.sources /etc/apt/sources.list.d/dadarecoos.list
	apt-get purge -y nickh-archive-keyring 2>/dev/null || true
fi
systemctl enable NetworkManager.service bluetooth.service zramswap.service 2>/dev/null || true

# Sobras do instalador que ninguém mais usa (Qt do Calamares em instalação niri etc.)
apt-get autoremove --purge -y || true
apt-get clean

echo "== fim $(date -Is)"
exit 0
