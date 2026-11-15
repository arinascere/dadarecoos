#!/usr/bin/env python3
"""Lista os pacotes que o instalador pediria ao apt para uma combinação de escolhas.

Uso: choice-packages.py plasma|niri [touch] [games] [homelab]
"""
import sys, yaml

M = "config/includes.chroot/etc/calamares/modules/"
out = []
for op in yaml.safe_load(open(M + "packages.conf"))["operations"]:
    out += op.get("install", [])
wanted = set(sys.argv[1:])
for f in ("packagechooser@desktop.conf", "packagechooser@extras.conf"):
    for item in yaml.safe_load(open(M + f))["items"]:
        if item["id"] in wanted:
            wanted.discard(item["id"])
            out += item["packages"]
assert not wanted, f"escolha desconhecida: {wanted}"
print(" ".join(out))
