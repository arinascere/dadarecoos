#!/usr/bin/env python3
"""Liga a ISO no QEMU (BIOS, 2 GB de RAM, rede) e salva capturas de tela.

Uso: boot-test.py ARQUIVO.iso PASTA_SAIDA
Também imprime a última captura em base64 no log (entre marcas), para poder
conferir sem baixar o artefato.
"""
import base64, json, os, socket, subprocess, sys, time

iso, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
qmp_path = "/tmp/qmp.sock"
subprocess.run(["qemu-img", "create", "-f", "qcow2", "/tmp/disk.qcow2", "24G"], check=True)
vm = subprocess.Popen([
    "qemu-system-x86_64", "-enable-kvm", "-cpu", "host", "-smp", "2", "-m", "2048",
    "-cdrom", iso, "-boot", "d", "-drive", "file=/tmp/disk.qcow2,if=virtio",
    "-nic", "user,model=virtio-net-pci", "-vga", "std", "-display", "none",
    "-serial", f"file:{out}/serial.log", "-qmp", f"unix:{qmp_path},server,nowait",
])


def qmp(sock, cmd, **args):
    sock.sendall(json.dumps({"execute": cmd, "arguments": args}).encode() + b"\n")
    buf = b""
    while b'"return"' not in buf and b'"error"' not in buf:
        buf += sock.recv(65536)
    return buf


try:
    time.sleep(3)
    s = socket.socket(socket.AF_UNIX)
    s.connect(qmp_path)
    s.recv(65536)
    qmp(s, "qmp_capabilities")
    time.sleep(8)
    qmp(s, "send-key", keys=[{"type": "qcode", "data": "ret"}])   # menu de boot
    last = None
    for t in (30, 75, 120, 180):
        time.sleep(t - (0 if last is None else last_t))
        last_t = t
        last = os.path.abspath(f"{out}/boot-{t:03d}s.png")
        print(t, qmp(s, "screendump", filename=last, format="png")[:120])
    time.sleep(1)
    assert os.path.getsize(last) > 0, "captura vazia"
    print("-----BEGIN SHOT-----")
    print(base64.b64encode(open(last, "rb").read()).decode())
    print("-----END SHOT-----")
finally:
    vm.kill()
