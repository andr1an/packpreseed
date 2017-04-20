#!/bin/bash
#
# Creates Debian 8 ISO with preseed.cfg and latecmd.sh script
# (useful for fast KVM virtual machine installation).
#
# WARNING! Generated ISO will ERASE all your virtual HDD!
#   Grub bootloader will be installed on /dev/vda (fails if your first HDD path
#   differs). To change this default behavior, edit d-i partman* sections in preseed.cfg.
#
# Author:
#   Sergey Andrianov <info@andrian.ninja>
#
# URL:
#   https://github.com/andr1an/packpreseed.git
#

# Needed files
PRESEED_FILE=preseed.cfg
LATECMD_SCRIPT=latecmd.sh

# Default settings
debian_image="/var/lib/libvirt/images/debian-8.7.1-amd64-netinst.iso"
iso_out="/var/lib/libvirt/images/debian-latest-preseed.iso"
preseed_hostname="andrian-debian"
preseed_username="andrian"
grub_timeout=10

print_usage() {
  cat <<-USAGE
Usage:
  $(basename $0) [-i image] [-o out] [-n name] [-u user] [-t timeout] [-h]
Options:
  -i  source Debian ISO image file
  -o  where to save preseeded ISO
  -n  hostname to use in preseed file
  -u  username to use in preseed file
  -t  timeout for CD boot loaders, seconds
  -h  print this help end exit
USAGE
}

errexit() {
  local exit_code=$1
  shift
  echo "$@" >&2
  exit $exit_code
}

while getopts ":i:o:n:u:t:h" opt; do
  case "$opt" in
    i)
      debian_image="$OPTARG"
      ;;
    o)
      iso_out="$OPTARG"
      ;;
    n)
      preseed_hostname="$OPTARG"
      ;;
    u)
      preseed_username="$OPTARG"
      ;;
    t)
      grub_timeout="$OPTARG"
      ;;
    h)
      print_usage
      exit
      ;;
    :)
      errexit 1 "Option -$OPTARG requires an argument."
      ;;
    \?)
      print_usage
      echo
      errexit 1 "Invalid option: -$OPTARG"
      ;;
  esac
done

cleanup() {
  [[ -d "$working_dir" ]] && rm -rf "$working_dir"
}

# Checks
[[ ! -f "$PRESEED_FILE" ]] && errexit 3 "Can't find preseed file: ${PRESEED_FILE}!"
[[ ! -f "$LATECMD_SCRIPT" ]] && errexit 3 "Can't find latecmd file: ${LATECMD_SCRIPT}!"

[[ $UID -ne 0 ]] && errexit 2 "Must be run as root!"

[[ ! -f "$debian_image" ]] && errexit 3 "Can't find image file: ${debian_image}!"
[[ -w "$iso_out" ]] || touch "$iso_out" 2>/dev/null \
  || errexit 3 "Can't create or overwrite target ISO: ${iso_out}!"
[[ "$grub_timeout" =~ ^[0-9]+$ ]] || errexit 3 "Invalid boot loader timeout: ${grub_timeout}!"

which genisoimage &>/dev/null || errexit 4 "Can't locate genisoimage!"
which rsync &>/dev/null || errexit 4 "Can't locate rsync!"
if ! lsmod | grep -qw loop; then
  modprobe loop || errexit 4 "Can't locate loopfs kernel module; 'modprobe loop' failed!"
fi

# Making preparations
working_dir=$(mktemp -d -t packpreseed.XXXXXXXXXX)
trap cleanup EXIT

[[ -d "$working_dir" ]] || errexit 1 "Can't create temp directory: ${working_dir}!"
sed -r -e '/^d-i netcfg\/(|get_)hostname/s# string.*$# string '"$preseed_hostname"'#' \
  -e '/^d-i passwd\/username/s# string.*$# string '"$preseed_username"'#' \
  "$PRESEED_FILE" > "${working_dir}/preseed.cfg"
cp "$LATECMD_SCRIPT" "${working_dir}/latecmd.sh"

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

echo "Setting boot loader timeout..."
isolinux_timeout=$(( $grub_timeout * 10 ))
chmod 644 boot/grub/grub.cfg isolinux/isolinux.cfg isolinux/prompt.cfg
sed -i "/^set theme=/a set timeout=$grub_timeout" boot/grub/grub.cfg
sed -i "s/timeout 0$/timeout $isolinux_timeout/" isolinux/isolinux.cfg
sed -i "s/timeout 0$/timeout $isolinux_timeout/" isolinux/prompt.cfg
chmod 444 boot/grub/grub.cfg isolinux/isolinux.cfg isolinux/prompt.cfg

echo 'Generating new ISO image...'
md5sum $(find -follow -type f ! -path './md5sum.txt') > md5sum.txt

popd > /dev/null # back to script working direcotry

genisoimage -o "$iso_out" -r -J -no-emul-boot -boot-load-size 4 \
  -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat \
  "${working_dir}/disk_modified"

echo -e "Custom ISO for host '$preseed_hostname' created:
  ${iso_out}"

chown qemu:qemu "$iso_out" 2>/dev/null || true

echo 'Done!'
