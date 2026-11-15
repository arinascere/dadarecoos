#!/bin/sh
# Roda no live (fora do chroot), depois do unpackfs: dá DNS ao sistema de destino
# para o apt funcionar lá dentro.
set -eu
root=$(findmnt -rno TARGET | grep -m1 '^/tmp/calamares-root' || true)
[ -n "$root" ] || { echo "destino do Calamares não encontrado"; exit 1; }
rm -f "$root/etc/resolv.conf"
cp -L /etc/resolv.conf "$root/etc/resolv.conf"
