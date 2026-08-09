#!/bin/bash -e

install -d -m 0755 "${ROOTFS_DIR}/opt/kaffeetuer"
install -m 0755 files/door_controller.py "${ROOTFS_DIR}/opt/kaffeetuer/door_controller.py"
install -m 0644 files/kaffeetuer.service "${ROOTFS_DIR}/etc/systemd/system/kaffeetuer.service"
