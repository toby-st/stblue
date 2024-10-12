#!/bin/sh
rpm-ostree install $(curl -s https://api.github.com/repos/VSCodium/vscodium/releases/latest | grep "browser_download_url.*x86_64.rpm\"" | cut -d : -f 2,3 | tr -d \") \
https://releases.threema.ch/web-electron/v1/release/Threema-Latest.rpm \
https://repo.protonvpn.com/fedora-40-stable/proton-vpn-gnome-desktop/proton-vpn-gnome-desktop-0.8.0-1.fc40.noarch.rpm
