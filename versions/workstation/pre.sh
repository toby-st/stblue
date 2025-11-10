#!/bin/sh

set -ouex pipefail
RELEASE="$(rpm -E %fedora)"

rpm --import https://packages.microsoft.com/keys/microsoft.asc

echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo

dnf install -y https://repo.protonvpn.com/fedora-${RELEASE}-unstable/protonvpn-beta-release/$(curl -s https://repo.protonvpn.com/fedora-${RELEASE}-unstable/protonvpn-beta-release/ | grep -oP 'href="\K[^"]*\.noarch\.rpm' | sort -V | tail -n 1)
