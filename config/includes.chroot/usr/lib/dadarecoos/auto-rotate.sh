#!/bin/bash
# Rotação automática no niri, via sensor (iio-sensor-proxy).
# ponytail: o mapa de ângulos pode vir invertido conforme o aparelho. Se girar errado, trocar 90 <-> 270.
out=$(niri msg -j outputs | jq -r 'keys[0]')
[ -n "$out" ] || exit 1
monitor-sensor --accel | while read -r line; do
	case "$line" in
		*"orientation changed: normal"*)    t=normal ;;
		*"orientation changed: bottom-up"*) t=180 ;;
		*"orientation changed: left-up"*)   t=90 ;;
		*"orientation changed: right-up"*)  t=270 ;;
		*) continue ;;
	esac
	niri msg output "$out" transform "$t"
done
