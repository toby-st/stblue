#!/bin/sh

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

INSTALL_PACKAGES=($(jq -r "(.install) | sort | unique[]" /tmp/packages.json))
REMOVE_PACKAGES=($(jq -r "(.remove) | sort | unique[]" /tmp/packages.json))

REMOVE_PACKAGES=($(rpm -qa --queryformat='%{NAME} ' ${REMOVE_PACKAGES[@]}))

rpm --import https://packages.microsoft.com/keys/microsoft.asc

echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo
rpm-ostree install \
    https://repo.protonvpn.com/fedora-42-unstable/protonvpn-beta-release/protonvpn-beta-release-1.0.3-1.noarch.rpm

sed -i 's/gpgcheck = 1/gpgcheck = 0/g' /etc/yum.repos.d/protonvpn-beta.repo
    
rpm-ostree override remove \
    ${REMOVE_PACKAGES[@]} \
    $(printf -- "--install=%s " ${INSTALL_PACKAGES[@]})
