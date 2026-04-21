set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

# Install kernel + matching kernel-devel + dkms. Installing both kernel and
# kernel-devel in one dnf transaction guarantees the versions match.
dnf install -y kernel kernel-devel dkms

KERNEL_VER="$(ls /usr/src/kernels | sort -V | tail -1)"

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

mkdir -p /etc/dkms/framework.conf.d
cat > /etc/dkms/framework.conf.d/stblue-signing.conf <<EOF
mok_signing_key="$MOK_PRIV"
mok_certificate="$MOK_DER"
EOF

# Fetch the displaylink RPM and install it with --nodeps --noscripts so we
# only unpack files. dnf install drags in the entire desktop stack (gtk3,
# pipewire, xorg…) for the userspace daemon, and its %post scriptlet fails
# in a container because it calls systemctl. We only need the evdi dkms
# source tree that lands in /usr/src/evdi-<ver>/.
RPM_URL=$(curl -s https://api.github.com/repos/displaylink-rpm/displaylink-rpm/releases/latest | grep -oP "https://github\.com/displaylink-rpm/displaylink-rpm/releases/download/[^/]+/fedora-${RELEASE}-[^\"]+\.x86_64\.rpm")
curl -L -o /tmp/displaylink.rpm "$RPM_URL"
rpm -i --nodeps --noscripts /tmp/displaylink.rpm
rm /tmp/displaylink.rpm

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

if [[ -f "$MOK_PRIV" ]]; then
  shred -u "$MOK_PRIV"
fi

# Record kernel version so the workflow can tag the image with it
mkdir -p /etc/kmod
echo "$KERNEL_VER" > /etc/kmod/kver

dnf -y autoremove
dnf clean all
