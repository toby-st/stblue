#!/bin/sh
curl -L https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo -o /etc/yum.repos.d/cuda-rhel9.repo
echo module_hotfixes=1 >> /etc/yum.repos.d/cuda-rhel9.repo
rpm-ostree install $(curl -s https://api.github.com/repos/VSCodium/vscodium/releases/latest | grep "browser_download_url.*x86_64.rpm\"" | cut -d : -f 2,3 | tr -d \") \
    kmod-nvidia-latest-dkms-545.23.06 \
    nvidia-driver-cuda-545.23.06 \
    nvidia-container-toolkit