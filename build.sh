#!/bin/sh

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

INSTALL_PACKAGES=($(jq -r "(.install) | sort | unique[]" /tmp/packages.json))
REMOVE_PACKAGES=($(jq -r "(.remove) | sort | unique[]" /tmp/packages.json))

REMOVE_PACKAGES=($(rpm -qa --queryformat='%{NAME} ' ${REMOVE_PACKAGES[@]}))

curl -L https://pkgs.tailscale.com/stable/fedora/tailscale.repo -o /etc/yum.repos.d/tailscale.repo

rpm-ostree install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${RELEASE}.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${RELEASE}.noarch.rpm \
    https://repo.protonvpn.com/fedora-40-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.1-2.noarch.rpm

if [[ "$RELEASE" == "39" ]]; then
    sed -i 's%free/fedora/releases%free/fedora/development%' /etc/yum.repos.d/rpmfusion-*.repo
fi

rpm-ostree override remove \
    ${REMOVE_PACKAGES[@]} \
    $(printf -- "--install=%s " ${INSTALL_PACKAGES[@]})
