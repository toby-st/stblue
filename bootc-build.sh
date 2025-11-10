#!/bin/sh

set -ouex pipefail
INSTALL_PACKAGES=($(jq -r "(.install) | sort | unique[]" /tmp/packages.json))
REMOVE_PACKAGES=($(jq -r "(.remove) | sort | unique[]" /tmp/packages.json))
mkdir /var/roothome || echo "directory already exists"

dnf install -y ${INSTALL_PACKAGES[@]}
dnf remove -y ${REMOVE_PACKAGES[@]}

dnf -y autoremove
dnf clean all