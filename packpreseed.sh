#!/bin/bash
#
# Creates Debian 8 ISO with preseed.cfg and latecmd.sh script
# (basically for fast kvm-qemu virtual machine installation)
#
# WARNING! Generated ISO will ERASE ALL your virtual HDD; grub bootloader will
#          be installed on /dev/vda (fails if your first HDD path differs).
#          To change this default behavior, edit preseed.cfg d-i partman* sections.
#
# Usage:
#   sudo ./packpreseed.sh debian-8.4.0-amd64-netinst.iso mypreseed.iso

PRESEED_FILE=preseed.cfg
LATECMD_SCRIPT=latecmd.sh

debian_image="${1:-/var/lib/libvirt/images/debian-8.5.0-amd64-netinst.iso}"
iso_out="${2:-/var/lib/libvirt/images/debian-latest-preseed.iso}"

errexit() {
  echo >&2 "$2"
  exit $1
}

# Checks
[[ $UID -ne 0 ]] && errexit 2 "Must be run as root!"

[[ ! -f "$PRESEED_FILE" ]] && errexit 3 "Can't find preseed file: ${PRESEED_FILE}!"
[[ ! -f "$LATECMD_SCRIPT" ]] && errexit 3 "Can't find latecmd file: ${LATECMD_SCRIPT}!"
[[ ! -f "$debian_image" ]] && errexit 3 "Can't find image file: ${debian_image}!"

which genisoimage &>/dev/null || errexit 4 "Can't locate genisoimage!"
which rsync &>/dev/null || errexit 4 "Can't locate rsync!"
lsmod | grep -q '^loop\b' || errexit 4 "Can't locate loopfs kernel module! Try: modprobe loop"

# Making preparations
working_dir=$(mktemp -d -t packpreseed.XXXXXXXXXX)

[[ ! -d "$working_dir" ]] || errexit 1 "Can't create temp directory: ${working_dir}!"
cp -v "$PRESEED_FILE" "${working_dir}/preseed.cfg"
cp -v "$LATECMD_SCRIPT" "${working_dir}/latecmd.sh"

# Working
echo 'Extracting ISO...'
mkdir "${working_dir}/disk_orig" "${working_dir}/disk_modified"
mount -o ro,loop "$debian_image" "${working_dir}/disk_orig"
pushd "$working_dir" > /dev/null # script working directory in stack
rsync -aH --exclude=TRANS.TBL disk_orig/ disk_modified
umount disk_orig
rmdir disk_orig

echo 'Hacking initrd...'
mkdir irmod
cd irmod
initrd_file="../disk_modified/install.amd/initrd.gz"
[[ ! -f "$initrd_file" ]] && errexit 5 "Can't locate initrd.gz in ${initrd_file}!"

gzip -d < "$initrd_file" \
  | cpio --extract --make-directories --no-absolute-filenames

cp -f ../preseed.cfg preseed.cfg

find . | cpio -H newc --create \
  | gzip -9 > "$initrd_file"

cd ../disk_modified

echo "Copying latecmd scipt..."
cp -f ../latecmd.sh ./

echo 'Generating new ISO image...'
md5sum $(find -follow -type f ! -path './md5sum.txt') > md5sum.txt

popd > /dev/null # back to script working direcotry

genisoimage -o "$iso_out" -r -J -no-emul-boot -boot-load-size 4 \
  -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat \
  "${working_dir}/disk_modified"

echo -e "Custom ISO created:
  ${iso_out}"

chown qemu:qemu "$iso_out" 2>/dev/null || true

# Cleanup
rm -rf "$working_dir"

echo 'Done!'
