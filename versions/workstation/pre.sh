#!/bin/sh

set -ouex pipefail
RELEASE="$(rpm -E %fedora)"

# only install English and French translations for packages added on top of the
# base image (saves ~500 MB of /usr/share/locale and friends)
echo "%_install_langs en:fr" > /etc/rpm/macros.image-language-conf

rpm --import https://packages.microsoft.com/keys/microsoft.asc

echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo

dnf install -y https://repo.protonvpn.com/fedora-${RELEASE}-unstable/protonvpn-beta-release/$(curl -s https://repo.protonvpn.com/fedora-${RELEASE}-unstable/protonvpn-beta-release/ | grep -oP 'href="\K[^"]*\.noarch\.rpm' | sort -V | tail -n 1)

curl -L "https://pkgs.tailscale.com/stable/fedora/tailscale.repo" -o /etc/yum.repos.d/tailscale.repo

# upstream Kubernetes repo for kubectl; each minor version has its own repo, so
# bump KUBE_MINOR to move to a new minor release
KUBE_MINOR="v1.37"
cat > /etc/yum.repos.d/kubernetes.repo <<REPO
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/${KUBE_MINOR}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${KUBE_MINOR}/rpm/repodata/repomd.xml.key
includepkgs=kubectl
REPO

# ublue-os COPR, restricted to gnome-rounded-blur so nothing else from it gets pulled in
cat > /etc/yum.repos.d/ublue-os-packages.repo <<REPO
[copr:copr.fedorainfracloud.org:ublue-os:packages]
name=Copr repo for packages owned by ublue-os
baseurl=https://download.copr.fedorainfracloud.org/results/ublue-os/packages/fedora-\$releasever-\$basearch/
type=rpm-md
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/ublue-os/packages/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
includepkgs=gnome-rounded-blur
REPO
