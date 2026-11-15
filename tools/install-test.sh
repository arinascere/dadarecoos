#!/bin/bash
# Simula a fase de instalação SEM o Calamares: abre o sistema da ISO numa pasta,
# roda prepare-apt.sh, instala os pacotes de uma combinação de escolhas com o mesmo
# comando do instalador e roda post-install.sh. Depois confere o resultado.
# Não cobre particionamento nem bootloader (módulos do Calamares testados pelo Debian).
#
# Uso (root, Debian): install-test.sh ARQUIVO.iso plasma|niri [touch] [games] [homelab]
set -euo pipefail
iso=$1; shift
choices=("$@")
T=/target
ok()   { echo "  ok: $*"; }
fail() { echo "  FALHOU: $*"; exit 1; }
want() { "$@" >/dev/null 2>&1 && ok "$*" || fail "$*"; }
chosen() { printf '%s\n' "${choices[@]}" | grep -qx "$1"; }

xorriso -osirrox on -indev "$iso" -extract /live/filesystem.squashfs /tmp/fs.squashfs >/dev/null 2>&1
unsquashfs -q -d "$T" /tmp/fs.squashfs
for m in proc sys dev dev/pts; do mount --bind "/$m" "$T/$m"; done
mount -t tmpfs tmpfs "$T/run"
rm -f "$T/etc/resolv.conf"; cp -L /etc/resolv.conf "$T/etc/resolv.conf"

echo "== prepare-apt"
chroot "$T" /usr/lib/dadarecoos/prepare-apt.sh
echo "== pacotes: ${choices[*]}"
# shellcheck disable=SC2046
chroot "$T" apt-get -q -y install $(python3 tools/choice-packages.py "${choices[@]}") </dev/null
echo "== post-install"
chroot "$T" env DADARECO_MEM_MB=3800 /usr/lib/dadarecoos/post-install.sh

echo "== conferência"
want test ! -e "$T/etc/systemd/system/dadareco-installer.service"
want test ! -e "$T/usr/bin/calamares"
want test ! -e "$T/usr/bin/cage"
want sh -c "ls $T/boot/vmlinuz-* $T/boot/initrd.img-*"
want chroot "$T" apt-get check
want python3 -c "import json; json.load(open('$T/etc/firefox-esr/policies/policies.json'))"
want grep -q vp9 "$T/etc/firefox-esr/policies/policies.json"        # sem GPU no CI = sem VP9
want grep -q PERCENT=60 "$T/etc/default/zramswap"
want test -e "$T/etc/systemd/system/multi-user.target.wants/NetworkManager.service"

if chosen plasma; then
	want test "$(readlink "$T/etc/systemd/system/display-manager.service")" = /usr/lib/systemd/system/sddm.service
	want grep -q ButtonsOnLeft "$T/etc/xdg/kwinrc"
	want grep -q blurEnabled=false "$T/etc/xdg/kwinrc"
	want test -e "$T/usr/bin/plasma-apply-lookandfeel"
	want test -e "$T/usr/bin/kwin_wayland"
	want test ! -e "$T/etc/apt/sources.list.d/noctalia-trixie.sources"
	if chosen touch; then
		want test -e "$T/usr/share/applications/com.github.maliit.keyboard.desktop"
		want grep -q 'DOCK_HEIGHT = 72' "$T/usr/share/plasma/look-and-feel/org.dadarecoos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js"
	fi
fi
if chosen niri; then
	want chroot "$T" niri validate -c /etc/skel/.config/niri/config.kdl
	want chroot "$T" noctalia --version
	want test -e "$T/etc/systemd/system/display-manager.service" -o -e "$T/etc/systemd/system/multi-user.target.wants/greetd.service" -o -e "$T/etc/systemd/system/graphical.target.wants/greetd.service"
	want test -s "$T/var/lib/noctalia-greeter/greeter.toml"
	want test -e "$T/etc/apt/sources.list.d/dadarecoos.list"
	if chosen touch; then
		want test -x "$T/usr/bin/squeekboard"
		want grep -q squeekboard "$T/etc/skel/.config/niri/config.kdl"
	fi
fi
if chosen games; then
	want chroot "$T" dpkg -s steam-installer
else
	want sh -c "! chroot $T dpkg --print-foreign-architectures | grep -q i386"
fi
if chosen homelab; then
	want chroot "$T" dpkg -s jellyfin
	want chroot "$T" testparm -s
	want test -d "$T/srv/midia/series"
	want grep -q HandleLidSwitch=ignore "$T/etc/systemd/logind.conf.d/dadareco-homelab.conf"
else
	want test ! -e "$T/etc/apt/sources.list.d/jellyfin.sources"
fi
echo "== tamanho do sistema instalado: $(du -sh --exclude="$T/proc" --exclude="$T/sys" --exclude="$T/dev" --exclude="$T/run" "$T" 2>/dev/null | cut -f1)"
echo "== avisos do post-install:"; grep -E 'AVISO|FALHOU' "$T/var/log/dadarecoos-install.log" || echo "  nenhum"
echo "TESTE OK: ${choices[*]}"
