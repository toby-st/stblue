#!/bin/sh

set -ouex pipefail
RELEASE="$(rpm -E %fedora)"

# dnf5 downloads 3 packages at a time by default; the main transaction in
# build.sh pulls ~2.5 GB across ~1500 packages.
if ! grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf; then
    printf 'max_parallel_downloads=10\n' >> /etc/dnf/dnf.conf
fi

rpm --import https://packages.microsoft.com/keys/microsoft.asc

echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo

dnf install -y https://repo.protonvpn.com/fedora-${RELEASE}-unstable/protonvpn-beta-release/$(curl -s https://repo.protonvpn.com/fedora-${RELEASE}-unstable/protonvpn-beta-release/ | grep -oP 'href="\K[^"]*\.noarch\.rpm' | sort -V | tail -n 1)

curl -L "https://pkgs.tailscale.com/stable/fedora/tailscale.repo" -o /etc/yum.repos.d/tailscale.repo
