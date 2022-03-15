# Prepare extroot/overlay automatically
mkdir -p /etc/hotplug.d/online
cat << "EOF" > /etc/hotplug.d/online/49-extroot-init
if [ ! -e /etc/extroot-init ] && lock -n /var/lock/extroot-init && opkg update
then
  . /etc/profile.d/opkg.sh
  if ! uci -q get fstab.overlay > /dev/null
  then
    DISK=/dev/mmcblk0
    DEVICE=${DISK}p3
    uci set opkg.rwm="opkg"
    uci add_list opkg.rwm.ipkg="fdisk"
    uci add_list opkg.rwm.ipkg="block-mount"
    uci add_list opkg.rwm.ipkg="kmod-fs-f2fs"
    uci add_list opkg.rwm.ipkg="f2fs-tools"
    uci add_list opkg.rwm.ipkg="partx-utils"
    uci add_list opkg.rwm.ipkg="mount-utils"
    uci commit opkg
    opkg restore rwm
    if [ ! -b ${DEVICE} ]
    then
      # Add root fs before mount root
      yes | fdisk -u ${DISK} << "EOCF"
n
p
3
1000000

w
EOCF
      partx -d - ${DEVICE}
      partx -a - ${DEVICE}
    fi
    if [ -b ${DEVICE} ]
    then
      mkfs.f2fs -l rootfs_data  ${DEVICE}
      eval $(block info ${DEVICE} | grep -o -e "UUID=\S*")
      uci -q delete fstab.overlay
      uci set fstab.overlay="mount"
      uci set fstab.overlay.uuid="${UUID}"
      uci set fstab.overlay.target="/overlay"
      uci set fstab.overlay.enabled_fsck="1"
      uci set fstab.overlay.enabled="1"
      uci commit fstab
      touch /etc/extroot-init
      lock -u /var/lock/extroot-init
      sync
      reboot
    fi
  fi
  touch /etc/extroot-init
  lock -u /var/lock/extroot-init    
fi
EOF
cat << "EOF" >> /etc/sysupgrade.conf
/etc/hotplug.d/online/49-extroot-init
EOF
