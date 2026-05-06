INSTALLROOT=/cm/images/default-no-cuda/

dnf remove nvidia-driver cuda-dcgm nvidia-fabricmanager --installroot=$INSTALLROOT

dnf remove nvidia-driver-cuda nvidia-driver-cuda-libs nvidia-driver-libs   kmod-nvidia-open-dkms nvidia-kmod-common nvidia-modprobe   nvidia-persistenced nvidia-imex libnvidia-* nvidia-libXNVCtrl*   --installroot=$INSTALLROOT