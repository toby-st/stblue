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
RPM_URL=$(curl -s https://api.github.com/repos/displaylink-rpm/displaylink-rpm/releases/latest | grep -oP "https://github\.com/displaylink-rpm/displaylink-rpm/releases/download/[^/]+/fedora-${RELEASE}-[^\"]+\.x86_64\.rpm") \
    && dnf install -y --setopt=tsflags=noscripts "$RPM_URL"

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

#install eza
curl -L "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.zip" -o /tmp/eza.zip \
    && unzip -o /tmp/eza.zip -d /tmp/eza && mv /tmp/eza/eza /usr/bin/
#install starship
curl -L "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/starship.tar.gz \
    && tar -xzf /tmp/starship.tar.gz -C /tmp && mv /tmp/starship /usr/bin/
#install virtctl
VERSION=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt) \
    && curl -L https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64 -o /usr/bin/virtctl && chmod +x /usr/bin/virtctl
#install argocd
curl -L https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 -o /usr/bin/argocd && chmod +x /usr/bin/argocd
#install cilium
curl -L https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz -o /tmp/cilium.tar.gz \
    && tar -xzf /tmp/cilium.tar.gz -C /tmp && mv /tmp/cilium /usr/bin/
#install kubeseal
VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep -oP '"tag_name": "\K[^"]+') \
    && curl -L "https://github.com/bitnami-labs/sealed-secrets/releases/download/${VERSION}/kubeseal-${VERSION#v}-linux-amd64.tar.gz" -o /tmp/kubeseal.tar.gz \
    && tar -xzf /tmp/kubeseal.tar.gz -C /tmp && mv /tmp/kubeseal /usr/bin/
#install velero
VERSION=$(curl -s https://api.github.com/repos/velero-io/velero/releases/latest | grep -oP '"tag_name": "\K[^"]+') \
    && curl -L "https://github.com/velero-io/velero/releases/download/${VERSION}/velero-${VERSION}-linux-amd64.tar.gz" -o /tmp/velero.tar.gz \
    && tar -xzf /tmp/velero.tar.gz -C /tmp && mv /tmp/velero-${VERSION}-linux-amd64/velero /usr/bin/
#install lazyssh
curl -L https://github.com/Adembc/lazyssh/releases/latest/download/lazyssh_Linux_x86_64.tar.gz -o /tmp/lazyssh.tar.gz \
    && tar -xzf /tmp/lazyssh.tar.gz -C /tmp && mv /tmp/lazyssh /usr/bin/
#install krew
curl -L https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-linux_amd64.tar.gz -o /tmp/krew.tar.gz \
    && tar -xzf /tmp/krew.tar.gz -C /tmp && mv /tmp/krew-linux_amd64  /usr/bin/kubectl-krew
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
