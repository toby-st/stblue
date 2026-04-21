set -ouex pipefail

# get current Fedora version
RELEASE="$(rpm -E %fedora)"

# search installed rpm packages for kernel to get version; `uname -r` does not work in a container environment
KERNEL_VER="$(rpm -qa | grep -E 'kernel-[0-9].*?' | cut -d'-' -f2,3)"
# install dkms
dnf install -y dkms

# MOK_DER (public cert) is stored in the repo - users need it to enroll in MOK
MOK_DER="/usr/local/etc/mok.der"
SIGN_FILE="/usr/src/kernels/$KERNEL_VER/scripts/sign-file"

# install displaylink driver (including evdi)
RPM_URL=$(curl -s https://api.github.com/repos/displaylink-rpm/displaylink-rpm/releases/latest | grep -oP "https://github\.com/displaylink-rpm/displaylink-rpm/releases/download/[^/]+/fedora-${RELEASE}-[^\"]+\.x86_64\.rpm") \
    && dnf install -y "$RPM_URL" || true

# build evdi kernel module
EVDI_VER="$(ls /usr/src | grep -oP '(?<=evdi-).+')" \
    && dkms build -m evdi -v "$EVDI_VER" -k "$KERNEL_VER" && dkms autoinstall --verbose --kernelver "$KERNEL_VER"

# Sign evdi kernel module for Secure Boot
if [[ -n "${MOK_PRIV_B64:-}" && -f "$MOK_DER" && -f "$SIGN_FILE" ]]; then
  echo "Signing evdi kernel module for Secure Boot..."
  MOK_PRIV="$(mktemp)"
  echo "$MOK_PRIV_B64" | base64 -d > "$MOK_PRIV"

  MODULE_PATH="/lib/modules/$KERNEL_VER/extra/evdi.ko"
  # DKMS may compress the module; decompress if needed
  if [[ -f "${MODULE_PATH}.xz" ]] && ! [[ -f "$MODULE_PATH" ]]; then
    xz -d "${MODULE_PATH}.xz"
  fi
  if [[ -f "$MODULE_PATH" ]]; then
    "$SIGN_FILE" sha256 "$MOK_PRIV" "$MOK_DER" "$MODULE_PATH"
    echo "Signed: $MODULE_PATH"
    xz --check=crc32 --lzma2=dict=512KiB "$MODULE_PATH"
  else
    echo "Warning: evdi module not found: $MODULE_PATH"
  fi

  shred -u "$MOK_PRIV"
else
  echo "Warning: MOK signing keys not found or sign-file missing. evdi module will be unsigned."
fi

dnf -y autoremove
dnf clean all
