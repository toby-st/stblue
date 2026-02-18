set -ouex pipefail

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
VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | grep -oP '"tag_name": "\K[^"]+') \
    && curl -L "https://github.com/vmware-tanzu/velero/releases/download/${VERSION}/velero-${VERSION}-linux-amd64.tar.gz" -o /tmp/velero.tar.gz \
    && tar -xzf /tmp/velero.tar.gz -C /tmp && mv /tmp/velero-${VERSION}-linux-amd64/velero /usr/bin/
#install lazyssh
curl -L https://github.com/Adembc/lazyssh/releases/latest/download/lazyssh_Linux_x86_64.tar.gz -o /tmp/lazyssh.tar.gz \
    && tar -xzf /tmp/lazyssh.tar.gz -C /tmp && mv /tmp/lazyssh /usr/bin/
#install eval
VERSION=$(curl -s https://api.github.com/repos/opendidac/opendidac_desktop_release/releases/latest | grep -oP '"tag_name": "\K[^"]+') \
    && dnf install -y https://github.com/opendidac/opendidac_desktop_release/releases/download/${VERSION}/opendidac_desktop-${VERSION#v}-1.x86_64.rpm

#fix read-only dir for global protect
mkdir /var/paloaltonetworks
ln -s /var/paloaltonetworks /opt/paloaltonetworks
#install global protect
dnf install -y /tmp/gp_ui.rpm

#install virtualbox
#script source https://github.com/ettfemnio/bazzite-virtualbox/blob/main/build.sh

# get current Fedora version
RELEASE="$(rpm -E %fedora)"

# search installed rpm packages for kernel to get version; `uname -r` does not work in a container environment
KERNEL_VER="$(rpm -qa | grep -E 'kernel-[0-9].*?' | cut -d'-' -f2,3)"
# install dkms
dnf install -y dkms
# get latest version number of VirtualBox
VIRTUALBOX_VER="$(curl -L https://download.virtualbox.org/virtualbox/LATEST.TXT)"
# URL to list of VirtualBox packages for latest version
VIRTUALBOX_VER_URL="https://download.virtualbox.org/virtualbox/$VIRTUALBOX_VER/"
# get all available VirtualBox Fedora rpm packages, sorted descending, and loop through them
VIRTUALBOX_RPMS="$(curl -L "$VIRTUALBOX_VER_URL" | grep -E -o 'VirtualBox.+?fedora[0-9]+?-.+?\.x86_64\.rpm' | sed -E -e 's/">.*//' | sort -Vr)"
for _VIRTUALBOX_RPM in $VIRTUALBOX_RPMS; do
  # extract the Fedora version from the file name
  FEDORA_VERSION="$(echo $_VIRTUALBOX_RPM | grep -E -o 'fedora[0-9]+' | grep -E -o '[0-9]+')"
  # if <= $RELEASE, break
  if [[ "$FEDORA_VERSION" -le "$RELEASE" ]]; then
    VIRTUALBOX_RPM="$_VIRTUALBOX_RPM"
    break
  fi
done
# URL to VirtualBox rpm
VIRTUALBOX_RPM_URL="$VIRTUALBOX_VER_URL$VIRTUALBOX_RPM"
echo "Using '$VIRTUALBOX_RPM_URL' for Fedora $RELEASE"
# download VirtualBox rpm
curl -L -o "/tmp/$VIRTUALBOX_RPM" "https://download.virtualbox.org/virtualbox/$VIRTUALBOX_VER/$VIRTUALBOX_RPM"
# install VirtualBox
dnf install -y "/tmp/$VIRTUALBOX_RPM"
# Insert hardcoded kernel version in VirtualBox scripts where necessary to get
# kernel modules to build. Without doing this, VirtualBox attempts to build the
# kernel modules for the kernel the GitHub runner host is running on.
# There may be a better way to do this, but since this is an atomic system
# anyway and these scripts don't persist across updates, it should not be an
# issue unless the kernel is changed downstream from here.
vbox_hardcode_kv () {
  local TARGET_FILE="$1"
  # sed expression to replace "uname -r" with "echo '[kernel version]'"
  local EXPR_UNAME_R="s/uname -r/echo '$KERNEL_VER'/g"
  # sed expression to replace "depmod -a" with "depmod -v '[kernel version]' -a"
  local EXPR_DEPMOD_A="s/depmod -a/depmod -v '$KERNEL_VER' -a/g"
  sed -i -e "$EXPR_UNAME_R" -e "$EXPR_DEPMOD_A" "$TARGET_FILE"
}
vbox_hardcode_kv /usr/lib/virtualbox/vboxdrv.sh
vbox_hardcode_kv /usr/lib/virtualbox/check_module_dependencies.sh
# run vboxconfig with KERN_VER set to build kernel modules
KERN_VER="$KERNEL_VER" /sbin/vboxconfig
# cat vbox log if it exists
if [[ -e /var/log/vbox-setup.log ]]; then
  cat /var/log/vbox-setup.log
fi

# Sign VirtualBox kernel modules for Secure Boot
# MOK_DER (public cert) is stored in the repo - users need it to enroll in MOK
MOK_DER="/usr/local/etc/mok.der"
SIGN_FILE="/usr/src/kernels/$KERNEL_VER/scripts/sign-file"

if [[ -n "${MOK_PRIV_B64:-}" && -f "$MOK_DER" && -f "$SIGN_FILE" ]]; then
  echo "Signing VirtualBox kernel modules for Secure Boot..."
  # Decode private key from secret to temp file
  MOK_PRIV="$(mktemp)"
  echo "$MOK_PRIV_B64" | base64 -d > "$MOK_PRIV"
  
  for module in vboxdrv vboxnetflt vboxnetadp; do
    MODULE_PATH="/lib/modules/$KERNEL_VER/misc/${module}.ko"
    if [[ -f "$MODULE_PATH" ]]; then
      "$SIGN_FILE" sha256 "$MOK_PRIV" "$MOK_DER" "$MODULE_PATH"
      echo "Signed: $MODULE_PATH"
    else
      echo "Warning: Module not found: $MODULE_PATH"
    fi
  done
  
  # Securely remove private key
  shred -u "$MOK_PRIV"
else
  echo "Warning: MOK signing keys not found or sign-file missing. Modules will be unsigned."
  echo "  MOK_PRIV_B64: (set: $(test -n "${MOK_PRIV_B64:-}" && echo yes || echo no))"
  echo "  MOK_DER: $MOK_DER (exists: $(test -f "$MOK_DER" && echo yes || echo no))"
  echo "  SIGN_FILE: $SIGN_FILE (exists: $(test -f "$SIGN_FILE" && echo yes || echo no))"
fi
# extension pack file name
EXTPACK_NAME="Oracle_VirtualBox_Extension_Pack-$VIRTUALBOX_VER.vbox-extpack"
# sha256 sums URL
SUMS_URL="${VIRTUALBOX_VER_URL}SHA256SUMS"
# sha256 for extpack file
HASH="$(curl -L $SUMS_URL | grep $EXTPACK_NAME | cut -d' ' -f1)"
# extension pack URL
EXTPACK_URL="${VIRTUALBOX_VER_URL}${EXTPACK_NAME}"
# download and install extension pack
EXTPACK_PATH="/tmp/extpack.vbox-extpack"
curl -L -o $EXTPACK_PATH "$EXTPACK_URL"
/usr/lib/virtualbox/VBoxExtPackHelperApp install \
  --base-dir /usr/lib/virtualbox/ExtensionPacks \
  --cert-dir /usr/share/virtualbox/ExtPackCertificates \
  --name "Oracle VirtualBox Extension Pack" \
  --tarball $EXTPACK_PATH \
  --sha-256 $HASH

mkdir -p /usr/lib/modules-load.d
cat > /usr/lib/modules-load.d/virtualbox.conf << EOF
# load virtualbox kernel drivers
vboxdrv
vboxnetflt
vboxnetflt
EOF

dnf install -y --setopt=tsflags=noscripts proton-vpn-gnome-desktop
dnf -y autoremove
dnf clean all