set -ouex pipefail

pipx install --system-site-packages --global solaar gns3-gui

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
#install virtualbox
VBOX_URL="https://download.virtualbox.org/virtualbox/rpm/fedora/40/x86_64/" \
    && VBOX_RPM=$(curl -s "$VBOX_URL" | grep -oP 'VirtualBox-[^"]+\.rpm' | sort -V | tail -1) \
    && dnf install -y "${VBOX_URL}${VBOX_RPM}"

dnf install -y --setopt=tsflags=noscripts proton-vpn-gnome-desktop
dnf -y autoremove
dnf clean all