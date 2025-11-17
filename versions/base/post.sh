#!/bin/sh

set -ouex pipefail

mkdir /usr/share/flatpak/remotes.d/ && \
    curl -L https://dl.flathub.org/repo/flathub.flatpakrepo -o /usr/share/flatpak/remotes.d/flathub.flatpakrepo
rm /usr/lib/systemd/system/flatpak-add-fedora-repos.service