#!/bin/sh

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

INSTALL_PACKAGES=($(jq -r "(.install) | sort | unique[]" /tmp/packages.json))
REMOVE_PACKAGES=($(jq -r "(.remove) | sort | unique[]" /tmp/packages.json))

REMOVE_PACKAGES=($(rpm -qa --queryformat='%{NAME} ' ${REMOVE_PACKAGES[@]}))

rpm-ostree install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${RELEASE}.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${RELEASE}.noarch.rpm

if [[ "$RELEASE" == "39" ]]; then
    sed -i 's%free/fedora/releases%free/fedora/development%' /etc/yum.repos.d/rpmfusion-*.repo
    rpm-ostree override replace \
     https://kojipkgs.fedoraproject.org//packages/pipewire/0.3.82/1.fc39/x86_64/pipewire-libs-0.3.82-1.fc39.x86_64.rpm \
     https://kojipkgs.fedoraproject.org//packages/pipewire/0.3.82/1.fc39/x86_64/pipewire-0.3.82-1.fc39.x86_64.rpm \
     https://kojipkgs.fedoraproject.org//packages/pipewire/0.3.82/1.fc39/x86_64/pipewire-alsa-0.3.82-1.fc39.x86_64.rpm \
     https://kojipkgs.fedoraproject.org//packages/pipewire/0.3.82/1.fc39/x86_64/pipewire-utils-0.3.82-1.fc39.x86_64.rpm \
     https://kojipkgs.fedoraproject.org//packages/pipewire/0.3.82/1.fc39/x86_64/pipewire-gstreamer-0.3.82-1.fc39.x86_64.rpm \
     https://kojipkgs.fedoraproject.org//packages/pipewire/0.3.82/1.fc39/x86_64/pipewire-jack-audio-connection-kit-0.3.82-1.fc39.x86_64.rpm \
     https://kojipkgs.fedoraproject.org//packages/pipewire/0.3.82/1.fc39/x86_64/pipewire-jack-audio-connection-kit-libs-0.3.82-1.fc39.x86_64.rpm \
     https://kojipkgs.fedoraproject.org//packages/pipewire/0.3.82/1.fc39/x86_64/pipewire-pulseaudio-0.3.82-1.fc39.x86_64.rpm 
fi



rpm-ostree override remove \
    ${REMOVE_PACKAGES[@]} \
    $(printf -- "--install=%s " ${INSTALL_PACKAGES[@]})
