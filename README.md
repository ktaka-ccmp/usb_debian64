# usb_debian64

This repository is for preparing a usb stick to boot diskless Debian Linux system.
The root directory will be mounted on tmpfs.

## Prepare content for USB sticks

The Makefile provided will prepare the followings. 

- Linux kernel
- rootfs.tgz
- initrd

Just `make all` to prepare everything and keep the fingers crossed.

```
# make 
Usage: make target 
 Available Targets 
	 all		: Make all files
	 
	 kernel		: Compile kernel
	 initrd		: Create initrd image
	 rootfs		: Create rootfs archive
	 copyfiles		: sync files/image to Build/image
	 
 Other Targets 
	 update:
	 update-dryrun:
		 		Sync ./image to ./mnt
	 			(This assumes usb partition is labeled with "usbdebian".)
```

If the user wants to modify the content on the default rootfs, changes should be made under the directory, `files/image/.custom/default/`.
If the user wants to add deb packages to the diskless Linux, changes should be made to the argument of `cdebootstrap` in the Makefile like the following:

```
 .PHONY: ${SRC_DIR}/rootfs_${DEBIAN}
 ${SRC_DIR}/rootfs_${DEBIAN}:
        mkdir -p $@
        cdebootstrap --include=openssh-server,openssh-client,rsync,pciutils,\
        tcpdump,strace,ca-certificates,telnet,curl,ncurses-term,\
        tree,psmisc,\
        sudo,aptitude,ca-certificates,apt-transport-https,\
        less,screen,ethtool,sysstat,tzdata,libpam0g,\
        sysvinit-core,sysvinit-utils,\
+       efibootmgr,sbsigntool,\
+       shim-signed,shim-unsigned,shim-helpers-amd64-signed,\
+       grub-efi-amd64-bin,grub-efi-amd64-signed,\
        sudo \
        ${DEBIAN} $@/ http://deb.debian.org/debian
        chroot $@/ bash -c 'echo "root:usb" | chpasswd'
```

## Format a USB stick and copy content

If the target USB is recognized as `/dev/sda`, type the following to make the bootable USB.

```
./install.sh sda
```

**Please pay special caution, so as not to wipe the content of wrong target USB or SSD!!**

## Boot the system

Insert the newly created USB to an arbitarary x64 PC or servers and boot the system from the USB device.

### Root Password

Please look for it in the Makefile.

### The usbimage utility

To be filled later.
