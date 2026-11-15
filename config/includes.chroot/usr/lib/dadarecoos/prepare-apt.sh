#!/bin/bash
# Roda DENTRO do sistema de destino, antes de instalar os pacotes escolhidos.
# Deixa o apt pronto: componentes non-free, i386 (Steam) e repositórios de terceiros.
# Os repositórios que não forem usados são removidos depois pelo post-install.sh.
# Também é executado no CI (tools/check-packages.py) para validar os nomes de pacote.
set -u
warn() { echo "AVISO: $*"; }

# 1. Debian com todos os componentes (drivers e firmware de terceiros)
if ! grep -rqs 'non-free-firmware' /etc/apt/sources.list /etc/apt/sources.list.d/; then
	rm -f /etc/apt/sources.list
	cat > /etc/apt/sources.list.d/debian.sources <<'SRC'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
SRC
fi

# 2. 32 bits para a Steam
# ponytail: i386 sempre ligado aqui; o post-install desliga se "Jogos" não foi marcado.
dpkg --add-architecture i386

# 3. DadarecoOS: niri e xwayland-satellite (não existem no Debian 13; compilados no nosso CI)
# ponytail: repositório sem assinatura ([trusted=yes]); a integridade depende do HTTPS do GitHub. Assinar com GPG quando houver mais usuários.
cat > /etc/apt/sources.list.d/dadarecoos.list <<'SRC'
deb [trusted=yes arch=amd64] https://github.com/arinascere/dadarecoos/releases/download/pkgs ./
SRC

# 4. Noctalia (repositório oficial do projeto)
tmp=$(mktemp -d)
if curl -fsSL -o "$tmp/keyring.deb" https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb \
	&& dpkg -i "$tmp/keyring.deb" \
	&& curl -fsSL -o /etc/apt/sources.list.d/noctalia-trixie.sources https://pkg.noctalia.dev/deb/noctalia-trixie.sources; then
	:
else
	warn "repositório do Noctalia indisponível; a opção niri + Noctalia vai falhar."
	rm -f /etc/apt/sources.list.d/noctalia-trixie.sources
fi
rm -rf "$tmp"

# 5. Jellyfin (repositório oficial do projeto)
install -d /etc/apt/keyrings
if curl -fsSL -o /etc/apt/keyrings/jellyfin.asc https://repo.jellyfin.org/jellyfin_team.gpg.key; then
	cat > /etc/apt/sources.list.d/jellyfin.sources <<'SRC'
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: trixie
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/jellyfin.asc
SRC
else
	warn "repositório do Jellyfin indisponível; o Jellyfin não será instalado."
fi

# 6. A Steam pergunta a licença via debconf; sem resposta a instalação automática falha.
#    A tela "Extras" do instalador avisa que marcar Jogos = aceitar a licença.
debconf-set-selections <<'SEL'
steam steam/question select I AGREE
steam steam/license note
steam-installer steam/question select I AGREE
steam-installer steam/license note
SEL

apt-get update || warn "apt-get update terminou com erro"
exit 0
