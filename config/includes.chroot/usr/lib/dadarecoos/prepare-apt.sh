#!/bin/bash
# Roda no sistema instalado ANTES de instalar os pacotes escolhidos (shellprocess@pre).
# Garante componentes non-free/contrib (drivers, firmware, Steam) e arquitetura i386.
set -eu
# ponytail: i386 sempre ligado (baixa um índice a mais). Ligar só com "Jogos" exige passar a escolha ao script.
dpkg --add-architecture i386

if ! grep -rqs 'non-free-firmware' /etc/apt/sources.list /etc/apt/sources.list.d/; then
	cat > /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
EOF
fi
apt-get update
