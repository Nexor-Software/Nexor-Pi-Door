#!/bin/bash -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 REPOSITORY_ROOT PI_GEN_ROOT" >&2
    exit 1
fi

REPOSITORY_ROOT=$(realpath "$1")
PI_GEN_ROOT=$(realpath "$2")

rm -rf "${PI_GEN_ROOT}/stage-nexor"
cp -a "${REPOSITORY_ROOT}/image/stage-nexor" "${PI_GEN_ROOT}/stage-nexor"
cp "${REPOSITORY_ROOT}/src/door_controller.py" \
    "${PI_GEN_ROOT}/stage-nexor/00-nexor/files/door_controller.py"
cp "${REPOSITORY_ROOT}/systemd/kaffeetuer.service" \
    "${PI_GEN_ROOT}/stage-nexor/00-nexor/files/kaffeetuer.service"
cp "${REPOSITORY_ROOT}/image/pi-gen-config" "${PI_GEN_ROOT}/config"

find "${PI_GEN_ROOT}/stage-nexor" -type f -exec chmod 0644 {} +
chmod +x \
    "${PI_GEN_ROOT}/stage-nexor/prerun.sh" \
    "${PI_GEN_ROOT}/stage-nexor/00-nexor/00-run.sh" \
    "${PI_GEN_ROOT}/stage-nexor/00-nexor/01-run-chroot.sh"

touch "${PI_GEN_ROOT}/stage2/SKIP_IMAGES"
