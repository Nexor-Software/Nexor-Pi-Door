#!/bin/bash -e

BOOT_CONFIG=/boot/firmware/config.txt

if ! grep -Eq '^[[:space:]]*gpio=27=op,dl([[:space:]]|$)' "${BOOT_CONFIG}"; then
    printf '\n# Nexor door: keep magnetic lock powered from early boot\ngpio=27=op,dl\n' >> "${BOOT_CONFIG}"
fi

if ! grep -Eq '^[[:space:]]*over_voltage=1([[:space:]]|$)' "${BOOT_CONFIG}"; then
    printf '# Nexor door: required for stable operation on this Pi\nover_voltage=1\n' >> "${BOOT_CONFIG}"
fi

if ! grep -Eq '^[[:space:]]*dtoverlay=disable-wifi([[:space:]]|$)' "${BOOT_CONFIG}"; then
    printf 'dtoverlay=disable-wifi\n' >> "${BOOT_CONFIG}"
fi

if ! grep -Eq '^[[:space:]]*dtoverlay=disable-bt([[:space:]]|$)' "${BOOT_CONFIG}"; then
    printf 'dtoverlay=disable-bt\n' >> "${BOOT_CONFIG}"
fi

systemctl enable pcscd.socket
systemctl enable kaffeetuer.service

for unit in \
    NetworkManager.service \
    NetworkManager-wait-online.service \
    bluetooth.service \
    hciuart.service \
    ssh.service \
    ssh.socket \
    wpa_supplicant.service
do
    systemctl disable "${unit}" 2>/dev/null || true
    systemctl mask "${unit}" 2>/dev/null || true
done

rm -f /boot/firmware/ssh /boot/ssh
rm -f /etc/NetworkManager/system-connections/*
rm -f /etc/wpa_supplicant/wpa_supplicant.conf

usermod --password '!' nexor
