#!/usr/bin/env python3
"""Confere se todo pacote citado pela DadarecoOS existe no apt.

Rode num Debian trixie depois de config/includes.chroot/usr/lib/dadarecoos/prepare-apt.sh
(o CI faz isso). Sai com erro listando os nomes que o apt não conhece: é o teste
que pega nome de pacote errado antes de gastar 20 minutos montando a ISO.
"""
import glob, re, subprocess, sys
import yaml

ROOT = "config/includes.chroot"
pkgs = {}                                   # nome -> onde foi citado


def add(name, where):
    pkgs.setdefault(name.strip(), where)


for line in open("config/package-lists/live.list.chroot"):
    line = line.split("#")[0].strip()
    if line:
        add(line, "live.list.chroot")

for f in glob.glob(f"{ROOT}/etc/calamares/modules/*.conf"):
    conf = yaml.safe_load(open(f)) or {}
    for item in conf.get("items", []):
        for p in item.get("packages", []):
            add(p, f)
    for op in conf.get("operations", []):
        for plist in op.values():
            for p in plist:
                add(p, f)

for f in glob.glob(f"{ROOT}/usr/lib/dadarecoos/*.sh"):
    for m in re.finditer(r"^\s*(?:.*&& )?inst ([a-z0-9 .+:-]+)$", open(f).read(), re.M):
        for p in m.group(1).split():
            add(p, f)

assert len(pkgs) > 60, f"só {len(pkgs)} pacotes encontrados: o extrator quebrou"

missing = []
for name, where in sorted(pkgs.items()):
    out = subprocess.run(["apt-cache", "policy", name], capture_output=True, text=True).stdout
    m = re.search(r"Candidate: (\S+)", out)
    if not m or m.group(1) == "(none)":
        missing.append(f"{name}  (citado em {where})")

print(f"{len(pkgs)} pacotes conferidos, {len(missing)} ausentes")
for m in missing:
    print("AUSENTE:", m)
sys.exit(1 if missing else 0)
