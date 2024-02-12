
TOP_DIR=${PWD}
IMG_DIR=${TOP_DIR}/Build/image/
SRC_DIR=${TOP_DIR}/Build/src/
FILE_DIR=${TOP_DIR}/files/

KERNEL_URI=http://www.kernel.org/pub/linux/kernel/v6.x/linux-6.7.4.tar.xz
KERNEL_FILE=$(notdir ${KERNEL_URI})
KERNEL=$(KERNEL_FILE:.tar.xz=)
KVER=$(subst linux-,,${KERNEL})
KVER_MINOR=-64usb01-pxe-compat

DEBIAN=bookworm

#BUSYBOX_URI=http://busybox.net/downloads/busybox-1.31.1.tar.bz2
BUSYBOX_URI=http://busybox.net/downloads/busybox-1.36.1.tar.bz2
BUSYBOX_FILE=$(notdir ${BUSYBOX_URI})
BUSYBOX=$(BUSYBOX_FILE:.tar.bz2=)
 
KERN_DIR=${SRC_DIR}/linux-${KVER}

default: 
	@sleep 0.3
	@echo  "Usage: make target "
	@echo  " Available Targets "
	@echo  "\t all		: Make all files"
	@echo  "\t "
	@echo  "\t kernel		: Compile kernel"
	@echo  "\t initrd		: Create initrd image"
	@echo  "\t rootfs		: Create rootfs archive"
	@echo  "\t copyfiles		: sync files/image to Build/image"
	@echo  "\t "
	@echo  " Other Targets "
	@echo  "\t update:"
	@echo  "\t update-dryrun:"
	@echo  "\t	 		Sync ./image to ./mnt"
	@echo  "\t 			(This assumes usb partition is labeled with \"usbdebian\".)"


.PHONY: default

all: 
	make prep
	make rootfs
	make initrd
	make kernel


rootfs: rootfs.tgz
initrd: initrd.img

.PHONY: all kernel  
.PHONY: install install-kernel install-rootfs 

.PHONY: prep

prep:
	aptitude update -y
	aptitude install -y debootstrap \
	cdebootstrap \
        libncurses5-dev \
        wget \
        xz-utils \
        bc gcc git bzip2 g++ \
        libtool \
        pkg-config \
        zlib1g-dev \
        libglib2.0-dev \
        autoconf \
        build-essential \
        socat lsof time \
        bridge-utils \
        libattr1-dev \
        libcap-dev \
        flex bison \
        debian-archive-keyring debian-keyring \
        libelf-dev \
	gdisk parted dosfstools \
	grub-efi-amd64 grub-pc-bin \


.PHONY: update
update:
	mkdir -p ${TOP_DIR}/mnt
	mount -L usbdebian ${TOP_DIR}/mnt
	if mountpoint ${TOP_DIR}/mnt > /dev/null  ; then \
		CONF=$(shell /bin/readlink ${TOP_DIR}/mnt/config.tgz);\
#		rsync  -arv ${IMG_DIR}/ ${TOP_DIR}/mnt/ ; \
#		rsync  -arvn --delete --exclude=custom --exclude=boot/grub --exclude=boot/efi --exclude=lost+found ${IMG_DIR}/ ${TOP_DIR}/mnt/ ; \
		rsync  -rptgoDrv --exclude=custom --exclude=boot --exclude=lost+found ${IMG_DIR}/ ${TOP_DIR}/mnt/ ; \
		rsync  -arv --exclude=grub --exclude=efi --exclude=lost+found ${IMG_DIR}/boot/ ${TOP_DIR}/mnt/boot/ ; \
		if [ "$$CONF" != "" ]; then (cd ${TOP_DIR}/mnt; ln -sf $$CONF config.tgz ) ; fi ;\
		ls -la ${TOP_DIR}/mnt ;\
		sync ;\
	fi
	umount ${TOP_DIR}/mnt

.PHONY: update-dryrun
update-dryrun:
	mkdir -p ${TOP_DIR}/mnt
	mount -L usbdebian ${TOP_DIR}/mnt
	if mountpoint ${TOP_DIR}/mnt > /dev/null  ; then \
		rsync  -rptgoDrvn --exclude=custom --exclude=boot --exclude=lost+found ${IMG_DIR}/ ${TOP_DIR}/mnt/ ; \
		rsync  -arvn --exclude=grub --exclude=efi --exclude=lost+found ${IMG_DIR}/boot/ ${TOP_DIR}/mnt/boot/ ; \
	fi
	umount ${TOP_DIR}/mnt

.PHONY: ${SRC_DIR}
${SRC_DIR}:
	mkdir -p $@

.PHONY: copyfiles
copyfiles:
	mkdir -p ${IMG_DIR}
	rsync -av ${FILE_DIR}/image/ ${IMG_DIR}

.PHONY: initrd.img
initrd.img: ${SRC_DIR}/initrd-usb-cpio copyfiles
	cp ${FILE_DIR}/init $</
	(cd $< ;find . | cpio -o -H newc | gzip -9 -n > ${IMG_DIR}/boot/initrd.img)

.PHONY: ${SRC_DIR}/initrd-usb-cpio
${SRC_DIR}/initrd-usb-cpio: ${SRC_DIR}/${BUSYBOX}/_install 
	mkdir -p $@
	rsync -a --delete $</ $@/
	(cd $@; mkdir -p sysroot proc sys dev mnt)

.PHONY: ${SRC_DIR}/${BUSYBOX}/_install
${SRC_DIR}/${BUSYBOX}/_install: ${SRC_DIR}
	if [ ! -d ${SRC_DIR}/${BUSYBOX} ]; then \
	wget -c ${BUSYBOX_URI} ; \
	tar xf ${BUSYBOX_FILE} -C ${SRC_DIR}; rm ${BUSYBOX_FILE} ; fi
	cp ${FILE_DIR}/dot.config.busybox ${SRC_DIR}/${BUSYBOX}/.config
	(cd ${SRC_DIR}/${BUSYBOX} ; \
	make menuconfig ; \
	time make -j 20 install )
	egrep  "CONF|^$$" ${SRC_DIR}/${BUSYBOX}/.config > ${FILE_DIR}/dot.config.busybox 

.PHONY: rootfs.tgz
rootfs.tgz: ${SRC_DIR}/rootfs_${DEBIAN} copyfiles
	if [ -f $</sbin/start-stop-daemon.REAL ]; then mv $</sbin/start-stop-daemon.REAL $</sbin/start-stop-daemon ; fi
	if [ -f $</usr/sbin/start-stop-daemon.REAL ]; then mv $</usr/sbin/start-stop-daemon.REAL $</usr/sbin/start-stop-daemon ; fi
	(cd $< ; tar cf - .)|gzip > ${IMG_DIR}/rootfs.tgz.0
	(cd $< ; tar cf - etc )|gzip > ${IMG_DIR}/config.tgz.0

.PHONY: ${SRC_DIR}/rootfs_${DEBIAN}
${SRC_DIR}/rootfs_${DEBIAN}:
	if [ -d $@/usr ]; then rm -rf $@/usr ; fi
	mkdir -p $@
	cdebootstrap --include=openssh-server,openssh-client,rsync,pciutils,\
	tcpdump,strace,ca-certificates,telnet,curl,ncurses-term,\
	tree,psmisc,\
	sudo,aptitude,ca-certificates,apt-transport-https,\
	less,screen,ethtool,sysstat,tzdata,libpam0g,\
	sysvinit-core,sysvinit-utils,\
	efibootmgr,sbsigntool,\
	shim-signed,shim-unsigned,shim-helpers-amd64-signed,\
	grub-efi-amd64-bin,grub-efi-amd64-signed,\
	sudo \
	${DEBIAN} $@/ http://deb.debian.org/debian
	chroot $@/ bash -c 'echo "root:usb" | chpasswd'
	rm $@/etc/localtime ; cp $@/usr/share/zoneinfo/Japan $@/etc/localtime
	apt-get -o RootDir=$@/ clean

kernel: ${SRC_DIR}/${KERNEL}/.config copyfiles
	ARCH=x86_64 nice -n 10 make -C ${SRC_DIR}/${KERNEL} -j20
	ARCH=x86_64 make -C ${SRC_DIR}/${KERNEL} modules_install INSTALL_MOD_PATH=${SRC_DIR} ; \
	LD_LIBRARY_PATH=${SRC_DIR} depmod -a -b ${SRC_DIR} ${KVER}${KVER_MINOR}
	(cd ${SRC_DIR}; tar cf - lib/modules/${KVER}${KVER_MINOR} | gzip > ${IMG_DIR}/modules.tgz ;\
	rm -rf lib )
	ARCH=x86_64 make -C ${SRC_DIR}/${KERNEL} install INSTALL_PATH=${IMG_DIR}/boot/
	(cd ${IMG_DIR}/boot/; ln -sf vmlinuz-${KVER}${KVER_MINOR} vmlinuz )
	(cp ${SRC_DIR}/${KERNEL}/.config ${FILE_DIR}/dot.config.kernel ; touch ${SRC_DIR}/${KERNEL}/.config)

.PHONY: ${SRC_DIR}/${KERNEL}/.config
${SRC_DIR}/${KERNEL}/.config: ${FILE_DIR}/dot.config.kernel ${SRC_DIR}
	if [ ! -d ${SRC_DIR}/${KERNEL} ]; then \
	(wget -c ${KERNEL_URI} ;\
	tar xf ${KERNEL_FILE} -C ${SRC_DIR}; rm ${KERNEL_FILE}) ; fi
	sed -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"${KVER_MINOR}\"/g' ${FILE_DIR}/dot.config.kernel > ${SRC_DIR}/${KERNEL}/.config
	ARCH=x86_64 make -C ${SRC_DIR}/${KERNEL} menuconfig
	(cd ${SRC_DIR}/${KERNEL}/; cp -v  .config .config.tmp ;\
	sed -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"${KVER_MINOR}\"/g' .config.tmp > .config ;\
	rm .config.tmp )
	cp ${SRC_DIR}/${KERNEL}/.config ${FILE_DIR}/dot.config.kernel

.PHONY: clean
clean:
	rm -rf ${TOP_DIR}/Build
	if mountpoint ${TOP_DIR}/mnt > /dev/null  ; then \
		umount ${TOP_DIR}/mnt ; fi 
	rm -rf ${TOP_DIR}/mnt 

