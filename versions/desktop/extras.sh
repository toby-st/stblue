#!/bin/sh
#echo module_hotfixes=1 >> /etc/yum.repos.d/cuda-rhel9.repo
rpm-ostree install $(curl -s https://api.github.com/repos/VSCodium/vscodium/releases/latest | grep "browser_download_url.*x86_64.rpm\"" | cut -d : -f 2,3 | tr -d \") \
    akmod-nvidia
curl -L https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo -o /etc/yum.repos.d/cuda-rhel9.repo


ln -s /usr/bin/ld.bfd /etc/alternatives/ld && ln -s /etc/alternatives/ld /usr/bin/ld
KERNEL_VERSION="$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
akmods --force --kernels "${KERNEL_VERSION}" --kmod "nvidia"

rpm-ostree install \
    xorg-x11-drv-nvidia-cuda \
    nvidia-container-toolkit