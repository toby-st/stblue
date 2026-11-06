#!/bin/sh

set -ouex pipefail
INSTALL_PACKAGES=($(jq -r "(.install) | sort | unique[]" /tmp/packages.json))
REMOVE_PACKAGES=($(jq -r "(.remove) | sort | unique[]" /tmp/packages.json))
mkdir /var/roothome || echo "directory already exists"

dnf install -y ${INSTALL_PACKAGES[@]}
# dnf can record a listed package as a dependency if another package requires it,
# and autoremove would then drop it (flatpak on F45, once gnome-software is gone)
dnf mark user -y $(jq -r '.install[] | select(startswith("@") | not)' /tmp/packages.json)
dnf remove -y ${REMOVE_PACKAGES[@]}

dnf -y autoremove
dnf clean all