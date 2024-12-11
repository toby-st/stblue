#!/bin/sh
rpm-ostree install $(curl -s https://api.github.com/repos/VSCodium/vscodium/releases/latest | grep "browser_download_url.*x86_64.rpm\"" | cut -d : -f 2,3 | tr -d \") https://releases.threema.ch/web-electron/v1/release/Threema-Latest.rpm https://download.copr.fedorainfracloud.org/results/juicedata/juicefs/fedora-39-x86_64/06988686-juicefs/juicefs-1.1.2-1.fc39.x86_64.rpm
