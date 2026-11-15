# DadarecoOS

Distro Linux baseada no **Debian 13 (trixie)**, feita para notebooks 2 em 1 simples (primeiro alvo: HP Pavilion x360 11-n226br, Celeron N2830, 4 GB, HDD) e que também serve de homelab/NAS.

> **Status: v0.1, esqueleto NÃO TESTADO.** Nenhuma ISO foi gerada nem iniciada ainda. Espere ajustes depois do primeiro boot real. Veja "Pendências".

## Como funciona

1. A **ISO é enxuta** (instalador + firmwares de rede, sem desktop).
2. O instalador (Calamares) **exige internet** antes de começar. Cabo conecta sozinho; Wi-Fi pelo `nmtui`; sem driver de Wi-Fi, use tethering USB do celular.
3. Você escolhe o ambiente: **KDE Plasma** ou **niri + Noctalia**.
4. Tela "Extras": **touchscreen** (já marcada se o aparelho tiver tela de toque), **Jogos (Steam)**, **Homelab/NAS**.
5. Os pacotes vêm da internet. Depois, `post-install.sh` aplica regras de hardware (microcode, GPU, Wi-Fi Broadcom, energia, zram em máquina com pouca RAM) e o ajuste de toque.

## Baixar

Releases: <https://github.com/arinascere/dadarecoos/releases>. Grave a ISO num pendrive (Balena Etcher ou `dd`).

## Construir

O GitHub Actions faz tudo: Actions → **Build ISO** → *Run workflow*, ou crie uma tag `v0.1.0`. A tag publica a ISO na Release.

Localmente (Debian/Ubuntu com `live-build`): `sudo lb config && sudo lb build`.

## Estrutura

| Caminho | Função |
|---|---|
| `auto/config` | opções do live-build (trixie, BIOS + UEFI 64 bits) |
| `config/package-lists/` | pacotes dentro da ISO |
| `config/includes.chroot/etc/calamares/` | telas e módulos do instalador |
| `config/includes.chroot/usr/lib/dadarecoos/` | `detect-hw.sh` (boot do live), `prepare-apt.sh`, `post-install.sh`, `auto-rotate.sh` |
| `.github/workflows/build-iso.yml` | build e release |

## Pendências conhecidas

- **Primeiro boot real.** Várias chaves de configuração foram escritas de memória e precisam de teste: instância `packagechooser` (`method: packages`, `default:`), chave `InputMethod` do `kwinrc`, flag `--hidden` do `wvkbd`, mapa de ângulos do `auto-rotate.sh`.
- **Noctalia.** O pacote e o repositório apt do Debian não foram confirmados. Sem eles, o niri é instalado **sem shell** e o usuário recebe `NOCTALIA-PENDENTE.txt`. Precisa do fork `noctalia-qs`, não do Quickshell comum.
- **niri no Debian.** Não confirmei se o pacote `niri` existe no trixie. Se não existir, a opção niri falha na instalação.
- **Teclado virtual no niri.** O auto-abrir ao tocar num campo pode não funcionar (depende de o niri expor `input-method-v2`). Hoje só abre pelo modo tablet.
- **Jellyfin** ainda não entra (não está no Debian; precisa do repositório oficial).
- **UEFI 32 bits** ainda não suportado (alguns Bay Trail têm).
- **Secure Boot:** NVIDIA proprietária só é instalada com ele desligado.
- **Tela de Wi-Fi** do instalador é o `nmtui` num terminal, precisa de teclado (ou `wvkbd`).
- **Aparência** (estilo macOS: dock embaixo, cantos arredondados, Inter) e **logo** ainda não existem. O logo atual é um quadrado provisório.
- Efeitos visuais pesados devem ser desligados em GPU fraca (regra ainda não escrita).

## Licença

A definir.
