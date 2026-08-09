#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this installer as root." >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BOOT_CONFIG=/boot/firmware/config.txt

apt-get update
apt-get install -y --no-install-recommends \
    libccid \
    pcscd \
    python3 \
    python3-pyscard

install -d -m 0755 /opt/kaffeetuer
install -m 0755 "$SCRIPT_DIR/src/door_controller.py" /opt/kaffeetuer/door_controller.py
install -m 0644 "$SCRIPT_DIR/systemd/kaffeetuer.service" /etc/systemd/system/kaffeetuer.service

if [ ! -f "$BOOT_CONFIG" ]; then
    echo "Missing $BOOT_CONFIG" >&2
    exit 1
fi

if ! grep -Eq '^[[:space:]]*gpio=27=op,dl([[:space:]]|$)' "$BOOT_CONFIG"; then
    printf '\n# Nexor door: keep magnetic lock powered from early boot\ngpio=27=op,dl\n' >> "$BOOT_CONFIG"
fi

if ! grep -Eq '^[[:space:]]*over_voltage=1([[:space:]]|$)' "$BOOT_CONFIG"; then
    printf '# Nexor door: required for stable operation on this Pi\nover_voltage=1\n' >> "$BOOT_CONFIG"
fi

systemctl enable pcscd.socket
systemctl daemon-reload
systemctl enable kaffeetuer.service
systemctl restart kaffeetuer.service

echo "Installed. Reboot once to verify the early GPIO boot state."
