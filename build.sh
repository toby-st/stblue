#!/bin/sh

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

INSTALL_PACKAGES=($(jq -r "(.install) | sort | unique[]" /tmp/packages.json))
REMOVE_PACKAGES=($(jq -r "(.remove) | sort | unique[]" /tmp/packages.json))

REMOVE_PACKAGES=($(rpm -qa --queryformat='%{NAME} ' ${REMOVE_PACKAGES[@]}))

curl -L https://pkgs.tailscale.com/stable/fedora/tailscale.repo -o /etc/yum.repos.d/tailscale.repo
curl -L https://repo.protonvpn.com/fedora-41-stable/public_key.asc -o /tmp/proton-key.asc

rpm-ostree install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${RELEASE}.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${RELEASE}.noarch.rpm \
    https://repo.protonvpn.com/fedora-${RELEASE}-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.2-1.noarch.rpm

sed -i 's/gpgcheck = 1/gpgcheck = 0/g' /etc/yum.repos.d/protonvpn-stable.repo
    
rpm-ostree override remove \
    ${REMOVE_PACKAGES[@]} \
    $(printf -- "--install=%s " ${INSTALL_PACKAGES[@]})
