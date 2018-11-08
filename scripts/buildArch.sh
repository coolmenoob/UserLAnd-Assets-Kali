#! /bin/bash

export DEBOOTSTRAP_DIR=output/debootstrap
export ARCH_DIR=output/${1}
export ROOTFS_DIR=$ARCH_DIR/rootfs

case "$1" in
    arm) export DEBOOTSTRAP_ARCH=armhf
        ;;
    arm64) export DEBOOTSTRAP_ARCH=arm64
        ;;
    x86) export DEBOOTSTRAP_ARCH=i386
        ;;
    x86_64) export DEBOOTSTRAP_ARCH=amd64
        ;;
    all) exit
        ;;
    *) echo "unsupported arch"
        exit
        ;;
esac

rm -rf $ARCH_DIR
mkdir -p $ARCH_DIR
rm -rf $ROOTFS_DIR
mkdir -p $ROOTFS_DIR
rm -rf $DEBOOTSTRAP_DIR
mkdir -p $DEBOOTSTRAP_DIR

wget -O output/kali-archive-keyring_2018.1_all.deb http://http.kali.org/pool/main/k/kali-archive-keyring/kali-archive-keyring_2018.1_all.deb
dpkg -i output/kali-archive-keyring_2018.1_all.deb
git clone git://git.kali.org/packages/debootstrap.git $DEBOOTSTRAP_DIR
apt install makedev
make -C $DEBOOTSTRAP_DIR devices.tar.gz
$DEBOOTSTRAP_DIR/debootstrap --foreign --arch=$DEBOOTSTRAP_ARCH --variant=minbase --include=sudo,dropbear,libgl1-mesa-glx,tightvncserver,xterm,xfonts-base,twm,expect,kali-archive-keyring,perl kali-rolling $ROOTFS_DIR http://http.kali.org/kali
case "$1" in
    arm) cp /usr/bin/qemu-arm-static $ROOTFS_DIR/usr/bin/
        ;;
    arm64) cp /usr/bin/qemu-aarch64-static $ROOTFS_DIR/usr/bin/
        ;;
esac
unset DEBOOTSTRAP_DIR
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS_DIR /debootstrap/debootstrap --second-stage

echo "127.0.0.1 localhost" > $ROOTFS_DIR/etc/hosts
echo "nameserver 8.8.8.8" > $ROOTFS_DIR/etc/resolv.conf
echo "nameserver 8.8.4.4" >> $ROOTFS_DIR/etc/resolv.conf

echo "#!/bin/sh" > $ROOTFS_DIR/etc/profile.d/userland.sh
echo "unset LD_PRELOAD" >> $ROOTFS_DIR/etc/profile.d/userland.sh
echo "unset LD_LIBRARY_PATH" >> $ROOTFS_DIR/etc/profile.d/userland.sh
echo "export LIBGL_ALWAYS_SOFTWARE=1" >> $ROOTFS_DIR/etc/profile.d/userland.sh
chmod +x $ROOTFS_DIR/etc/profile.d/userland.sh

echo "deb http://http.kali.org/kali kali-rolling main contrib non-free" > $ROOTFS_DIR/etc/apt/sources.list
echo "#deb-src http://http.kali.org/kali kali-rolling contrib non-free" >> $ROOTFS_DIR/etc/apt/sources.list

cp scripts/shrinkRootfs.sh $ROOTFS_DIR
chmod 777 $ROOTFS_DIR/shrinkRootfs.sh
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS_DIR ./shrinkRootfs.sh
rm $ROOTFS_DIR/shrinkRootfs.sh

tar --exclude='dev/*' -czvf $ARCH_DIR/rootfs.tar.gz -C $ROOTFS_DIR .

DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS_DIR apt-get update
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS_DIR apt-get -y install build-essential

#build disableselinux to go with this release
cp scripts/disableselinux.c $ROOTFS_DIR
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS_DIR gcc -shared -fpic disableselinux.c -o libdisableselinux.so 
cp $ROOTFS_DIR/libdisableselinux.so $ARCH_DIR/libdisableselinux.so

#get busybox to go with the release
DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
 LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFS_DIR apt-get -y install busybox-static 
cp $ROOTFS_DIR/bin/busybox $ARCH_DIR/busybox
