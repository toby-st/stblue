set -ouex pipefail

if ! rpm -q --whatprovides /usr/bin/sh >/dev/null 2>&1; then
    echo "rpmdb file index is unusable, rebuilding it" >&2
    rpm --rebuilddb || true
    REBUILT="$(ls -d /usr/share/rpmrebuilddb.* 2>/dev/null | head -1 || true)"
    if [[ -z "$REBUILT" || ! -f "$REBUILT/rpmdb.sqlite" ]]; then
        echo "ERROR: rpm --rebuilddb produced no usable database." >&2
        exit 1
    fi
    rm -f /usr/share/rpm/rpmdb.sqlite \
          /usr/share/rpm/rpmdb.sqlite-shm \
          /usr/share/rpm/rpmdb.sqlite-wal
    cp "$REBUILT/rpmdb.sqlite" /usr/share/rpm/rpmdb.sqlite
    rm -rf "$REBUILT"
    # Fail loudly rather than carrying a half-repaired database into the image.
    rpm -q --whatprovides /usr/bin/sh >/dev/null
fi

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

mkdir -p /usr/share/flatpak/remotes.d/ && \
    curl -L https://dl.flathub.org/repo/flathub.flatpakrepo -o /usr/share/flatpak/remotes.d/flathub.flatpakrepo
rm /usr/lib/systemd/system/flatpak-add-fedora-repos.service || true

# Install displaylink (userspace + evdi dkms source). tsflags=noscripts skips
# the %post systemctl invocations that fail in a container.
LATEST_RELEASE=$(curl -s https://api.github.com/repos/displaylink-rpm/displaylink-rpm/releases/latest)
RPM_URL=$(echo "$LATEST_RELEASE" | grep -oP "https://github\.com/displaylink-rpm/displaylink-rpm/releases/download/[^/]+/fedora-${RELEASE}-[^\"]+\.x86_64\.rpm" || true)
if [[ -z "$RPM_URL" ]]; then
    RPM_URL=$(echo "$LATEST_RELEASE" | grep -oP "https://github\.com/displaylink-rpm/displaylink-rpm/releases/download/[^/]+/fedora-43-[^\"]+\.x86_64\.rpm" || true)
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

pipx install --backend pip --system-site-packages --global solaar

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
#install azure-cli from Microsoft's package repo
rpm --import https://packages.microsoft.com/keys/microsoft.asc
cat > /etc/yum.repos.d/azure-cli.repo <<'EOF'
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
dnf install -y azure-cli


#install latest stable proton-pass
PROTON_PASS_JSON=$(curl -s https://proton.me/download/PassDesktop/linux/x64/version.json)
PROTON_PASS_RPM_URL=$(echo "$PROTON_PASS_JSON" | jq -r '[.Releases[] | select(.CategoryName == "Stable")][0].File[] | select(.Identifier | contains("rpm")) | .Url')
PROTON_PASS_SHA512=$(echo "$PROTON_PASS_JSON" | jq -r '[.Releases[] | select(.CategoryName == "Stable")][0].File[] | select(.Identifier | contains("rpm")) | .Sha512CheckSum')
if [[ -z "$PROTON_PASS_RPM_URL" || -z "$PROTON_PASS_SHA512" ]]; then
    echo "ERROR: could not determine latest stable proton-pass rpm." >&2
    exit 1
fi
curl -L "$PROTON_PASS_RPM_URL" -o /tmp/proton-pass.rpm
echo "$PROTON_PASS_SHA512  /tmp/proton-pass.rpm" | sha512sum -c -
dnf install -y /tmp/proton-pass.rpm
rpm -q proton-pass

#install latest stable proton-pass-cli
PASS_CLI_JSON=$(curl -s https://proton.me/download/pass-cli/versions.json)
PASS_CLI_URL=$(echo "$PASS_CLI_JSON" | jq -r '.passCliVersions.urls.linux.x86_64.url')
PASS_CLI_HASH=$(echo "$PASS_CLI_JSON" | jq -r '.passCliVersions.urls.linux.x86_64.hash')
if [[ -z "$PASS_CLI_URL" || -z "$PASS_CLI_HASH" ]]; then
    echo "ERROR: could not determine latest stable pass-cli binary." >&2
    exit 1
fi
curl -L "$PASS_CLI_URL" -o /usr/local/bin/pass-cli
echo "$PASS_CLI_HASH  /usr/local/bin/pass-cli" | sha256sum -c -
chmod +x /usr/local/bin/pass-cli


#install eval
VERSION=$(curl -s https://api.github.com/repos/opendidac/opendidac_desktop_release/releases/latest | grep -oP '"tag_name": "\K[^"]+')
if [[ -z "$VERSION" ]]; then
    echo "ERROR: could not determine latest opendidac_desktop release version." >&2
    exit 1
fi
curl -L "https://github.com/opendidac/opendidac_desktop_release/releases/download/${VERSION}/opendidac_desktop-${VERSION#v}-1.x86_64.rpm" -o /tmp/opendidac_desktop.rpm
rpm -i --replacefiles /tmp/opendidac_desktop.rpm
rpm -q opendidac_desktop

#install latest staruml
STARUML_BASE="https://files.staruml.io/releases-v7"
STARUML_YML=$(curl -s "$STARUML_BASE/latest-linux.yml")
STARUML_RPM=$(echo "$STARUML_YML" | grep -oP '^\s*- url: \K\S+\.x86_64\.rpm' || true)
STARUML_SHA512=$(echo "$STARUML_YML" | grep -A1 -F "$STARUML_RPM" | grep -oP '^\s*sha512: \K\S+' || true)
if [[ -z "$STARUML_RPM" || -z "$STARUML_SHA512" ]]; then
    echo "ERROR: could not determine latest staruml rpm." >&2
    exit 1
fi
curl -L "$STARUML_BASE/$STARUML_RPM" -o /tmp/staruml.rpm
# latest-linux.yml carries a base64-encoded sha512, not hex
if [[ "$(openssl dgst -sha512 -binary /tmp/staruml.rpm | base64 -w0)" != "$STARUML_SHA512" ]]; then
    echo "ERROR: staruml rpm checksum mismatch." >&2
    exit 1
fi
dnf install -y /tmp/staruml.rpm
rpm -q StarUML

#symlink terraform to opentofu
ln -s /usr/sbin/tofu /usr/bin/terraform

#add CUCurses.h to path
cp /usr/share/doc/CUnit/html/headers/CUCurses.h /usr/include/CUnit/CUCurses.h

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
