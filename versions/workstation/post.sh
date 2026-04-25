set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

MOK_DER="/usr/local/etc/mok.der"
MOK_PRIV="/tmp/mok.priv"

# Require real MOK signing material. Refuse to build an unsigned (or
# throwaway-signed) evdi — such modules won't load under Secure Boot and
# silently shipping them would be worse than failing the build.
if [[ -z "${MOK_PRIV_B64:-}" ]]; then
  echo "ERROR: MOK_PRIV_B64 secret not provided — cannot sign evdi." >&2
  exit 1
fi
if [[ ! -f "$MOK_DER" ]]; then
  echo "ERROR: $MOK_DER missing — cannot sign evdi." >&2
  exit 1
fi

echo "$MOK_PRIV_B64" | base64 -d > "$MOK_PRIV"
if ! openssl rsa -in "$MOK_PRIV" -check -noout >/dev/null 2>&1; then
  echo "ERROR: MOK_PRIV_B64 did not decode to a valid RSA private key." >&2
  exit 1
fi

dnf install -y dkms

KERNEL_VER="$(ls /usr/src/kernels | sort -V | tail -1)"

mkdir -p /etc/dkms/framework.conf.d
cat > /etc/dkms/framework.conf.d/stblue-signing.conf <<EOF
mok_signing_key="$MOK_PRIV"
mok_certificate="$MOK_DER"
EOF

mkdir /usr/share/flatpak/remotes.d/ && \
    curl -L https://dl.flathub.org/repo/flathub.flatpakrepo -o /usr/share/flatpak/remotes.d/flathub.flatpakrepo
rm /usr/lib/systemd/system/flatpak-add-fedora-repos.service

# Install displaylink (userspace + evdi dkms source). tsflags=noscripts skips
# the %post systemctl invocations that fail in a container.
LATEST_RELEASE=$(curl -s https://api.github.com/repos/displaylink-rpm/displaylink-rpm/releases/latest)
RPM_URL=$(echo "$LATEST_RELEASE" | grep -oP "https://github\.com/displaylink-rpm/displaylink-rpm/releases/download/[^/]+/fedora-${RELEASE}-[^\"]+\.x86_64\.rpm")
if [[ -z "$RPM_URL" ]]; then
    RPM_URL=$(echo "$LATEST_RELEASE" | grep -oP "https://github\.com/displaylink-rpm/displaylink-rpm/releases/download/[^/]+/fedora-43-[^\"]+\.x86_64\.rpm")
fi
dnf install -y --setopt=tsflags=noscripts "$RPM_URL"

# Build and install evdi. dkms handles signing (per framework.conf above)
# and xz-compressing the module into /lib/modules/$KERNEL_VER/extra/.
EVDI_VER="$(ls /usr/src | grep -oP '(?<=evdi-).+')"
dkms add -m evdi -v "$EVDI_VER"
dkms build -m evdi -v "$EVDI_VER" -k "$KERNEL_VER"
dkms autoinstall --verbose --kernelver "$KERNEL_VER"

MODULE_PATH_XZ="/lib/modules/$KERNEL_VER/extra/evdi.ko.xz"
if [[ ! -f "$MODULE_PATH_XZ" ]]; then
    echo "evdi module not found at $MODULE_PATH_XZ"
    exit 1
fi

shred -u "$MOK_PRIV"

pipx install --system-site-packages --global solaar

# Load Logitech HID kernel modules on boot
curl https://raw.githubusercontent.com/pwr-Solaar/Solaar/refs/heads/master/rules.d-uinput/42-logitech-unify-permissions.rules > /etc/udev/rules.d/42-logitech-unify-permissions.rules
echo "hid-logitech-dj" >> /etc/modules-load.d/logitech.conf && echo hid-logitech-hidpp >> /etc/modules-load.d/logitech.conf

GHCR="ghcr.io/toby-st/stblue/rpm"
TOOLS=(eza starship virtctl argocd cilium kubeseal velero lazyssh krew)
mkdir -p /tmp/extra-rpms
for tool in "${TOOLS[@]}"; do
    (cd /tmp/extra-rpms && oras pull "ghcr.io/toby-st/stblue/rpm/${tool}:latest")
done
mapfile -t rpms < <(find /tmp/extra-rpms -name '*.rpm')
dnf install -y "${rpms[@]}"
rm -rf /tmp/extra-rpms
#install eval
VERSION=$(curl -s https://api.github.com/repos/opendidac/opendidac_desktop_release/releases/latest | grep -oP '"tag_name": "\K[^"]+') \
    && dnf install -y https://github.com/opendidac/opendidac_desktop_release/releases/download/${VERSION}/opendidac_desktop-${VERSION#v}-1.x86_64.rpm

#symlink terraform to opentofu
ln -s /usr/sbin/tofu /usr/bin/terraform

#enable tailscale
systemctl enable tailscaled

#fix read-only dir for global protect
mkdir /var/paloaltonetworks
ln -s /var/paloaltonetworks /opt/paloaltonetworks
#install global protect
dnf install -y /tmp/gp_ui.rpm

#install EVE-NG client tools
wget -qO- https://raw.githubusercontent.com/SmartFinn/eve-ng-integration/master/install.sh | sh

dnf install -y --setopt=tsflags=noscripts proton-vpn-gnome-desktop
dnf -y autoremove
dnf clean all
