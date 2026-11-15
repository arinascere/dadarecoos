#!/bin/sh
# Aplica o visual DadarecoOS uma única vez, no primeiro login de cada usuário.
flag="${XDG_CONFIG_HOME:-$HOME/.config}/dadarecoos-firstrun-done"
[ -e "$flag" ] && exit 0
mkdir -p "$(dirname "$flag")" && : > "$flag"
plasma-apply-lookandfeel --apply org.dadarecoos.desktop --resetLayout
