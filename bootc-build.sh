#!/bin/sh

set -ouex pipefail
INSTALL_PACKAGES=($(jq -r "(.install) | sort | unique[]" /tmp/packages.json))
REMOVE_PACKAGES=($(jq -r "(.remove) | sort | unique[]" /tmp/packages.json))
mkdir /var/roothome || echo "directory already exists"

dnf install -y ${INSTALL_PACKAGES[@]}
dnf remove -y --exclude=flatpak,flatpak-selinux ${REMOVE_PACKAGES[@]}

dnf -y autoremove
# Only drop the downloaded packages, not the repo metadata: post.sh runs several
# more dnf transactions and a full `clean all` here made each of them re-fetch
# ~100 MB of metadata. post.sh still ends with `dnf clean all`.
dnf clean packages
