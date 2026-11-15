# DadarecoOS

Distro Linux baseada no **Debian 13 (trixie)** para notebooks 2 em 1 simples, que também serve de homelab/NAS. Primeiro alvo: HP Pavilion x360 11-n226br (Celeron N2830, 4 GB, HDD, tela de toque).

> **Status: v0.2, ainda não instalada em hardware real.** O que o CI verifica a cada build está em "O que é testado". O que só o notebook pode confirmar está em "Falta testar no aparelho".

## Como funciona

1. A **ISO é enxuta**: instalador e firmwares de rede e vídeo, sem desktop.
2. O instalador **exige internet**. Cabo conecta sozinho. Para Wi-Fi abre o `nmtui`. Sem driver de Wi-Fi, ligue o celular por USB e ative o tethering.
3. Você escolhe o ambiente: **KDE Plasma** ou **niri + Noctalia**.
4. Tela "Extras":
   - **Tela sensível ao toque** (já marcada se o aparelho tiver uma): teclado virtual que abre ao tocar num campo de texto, rotação automática, alvos maiores.
   - **Jogos**: Steam e drivers de 32 bits.
   - **Homelab / NAS**: Jellyfin, Samba, tampa fechada sem suspender, pasta `/srv/midia`.
5. Os pacotes vêm da internet. Depois, o `post-install.sh` aplica regras conforme o hardware.

### Regras de hardware

| Detectou | Faz |
|---|---|
| CPU Intel / AMD | microcode correspondente |
| GPU Intel / AMD | drivers VA-API (vídeo acelerado) |
| GPU NVIDIA | driver proprietário, só com Secure Boot desligado |
| Wi-Fi Broadcom sem driver livre | `broadcom-sta-dkms` |
| 4 GB de RAM ou menos | zram maior, sem desfoque, animações curtas, sem indexador de arquivos |
| Sem VP9 por hardware (caso do N2830) | Firefox pede H.264 ao YouTube, que a GPU decodifica |
| HDD giratório | escalonador BFQ |

### Aparência

Estilo próximo ao macOS, com arte original: barra fina no topo (menu, menu global, bandeja, relógio), dock flutuante centralizado embaixo, botões da janela à esquerda, fonte Inter, tema escuro com lavanda. No niri, o Noctalia faz a barra, o lançador e o dock (`noctalia msg dock-toggle`).

## Baixar

Releases: <https://github.com/arinascere/dadarecoos/releases>. A Release `pkgs` **não é a ISO**: é o repositório apt interno. Grave a ISO num pendrive com Balena Etcher ou `dd`.

## Construir

Actions → **Build ISO** → *Run workflow* gera a ISO como artefato. Uma tag `v0.2.0` também publica na Release.

O niri não existe no Debian 13. O workflow **Build packages** compila o niri e o `xwayland-satellite` e publica na Release `pkgs`, que o instalador usa como repositório apt.

## Estrutura

| Caminho | Função |
|---|---|
| `auto/config` | opções do live-build |
| `config/package-lists/live.list.chroot` | pacotes dentro da ISO (e base do sistema instalado) |
| `config/includes.chroot/etc/calamares/` | telas e sequência do instalador |
| `config/includes.chroot/usr/lib/dadarecoos/` | `detect-hw.sh`, `net-prep.sh`, `prepare-apt.sh`, `post-install.sh` |
| `config/includes.chroot/usr/share/dadarecoos/` | configs do niri e do Plasma |
| `config/includes.chroot/usr/share/plasma/look-and-feel/` | layout do Plasma |
| `tools/` | `check-packages.py`, `boot-test.py`, `make-art.py` |

## O que é testado (CI)

- Todos os nomes de pacote existem nos repositórios (`tools/check-packages.py`).
- O niri compilado instala num Debian 13 limpo e aceita o nosso `config.kdl`, com e sem os ajustes de toque.
- A ISO é montada e ligada numa máquina virtual, com capturas de tela.

## Falta testar no aparelho

- **Uma instalação completa.** O CI liga a ISO, mas não percorre o instalador até o fim.
- Toque: teclado virtual (Maliit no Plasma, Squeekboard no niri), rotação e o teclado dentro do instalador.
- Layout do Plasma (`org.kde.plasma.desktop-layout.js`) e tela de login em Wayland.
- Tela de login do Noctalia (`greeter.toml`).
- Wi-Fi do HP x360 e boot em UEFI.

## Limitações conhecidas

- O repositório apt da DadarecoOS **não é assinado** (`trusted=yes`); depende do HTTPS do GitHub.
- A tela de Wi-Fi do instalador (`nmtui`) precisa de teclado físico.
- O niri não tem gestos de toque. Para uso como tablet, prefira o Plasma.
- Neste hardware o Jellyfin só serve bem em *direct play* (sem converter vídeo).
- Marcar "Jogos" aceita a licença da Steam automaticamente.

## Licença

Scripts e configurações: a definir. `usr/share/dadarecoos/niri/config.kdl` deriva do config padrão do niri (GPL-3.0-or-later).
