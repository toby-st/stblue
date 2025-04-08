#!/bin/sh
rpm-ostree install $(curl -s https://api.github.com/repos/VSCodium/vscodium/releases/latest | grep "browser_download_url.*x86_64.rpm\"" | cut -d : -f 2,3 | tr -d \") https://releases.threema.ch/web-electron/v1/release/Threema-Latest.rpm
