# packpreseed

Script creates a personalized Debian 8 Jessie x86_64 ISO image ready for fast
KVM installation. It configures your ssh service, sudo and installs [Puppet](https://puppetlabs.com).

**WARNING!** Generated installer will ERASE ALL your virtual HDD by default!
To change this behavior, change `d-i partman*` parameters in `preseed.cfg`.

Grub bootloader will be installed on /dev/vda (fails if your first HDD path
differs); see `d-i grub-installer*` in `preseed.cfg`.

## Requirements

 - `genisoimage` utility
 - `rsync` utility
 - `loopfs` kernel module

## Usage

    packpreseed.sh [-i image] [-o out] [-n name] [-u user] [-t timeout] [-h]

    Options:
      -i  source Debian ISO image file
      -o  where to save preseeded ISO
      -n  hostname to use in preseed file
      -u  username to use in preseed file
      -t  timeout for CD boot loaders, seconds
      -h  print this help end exit

Example:

    sudo ./packpreseed.sh -i debian-8.8.0-amd64-netinst.iso -o mypreseed.iso

## License

Code released under the [MIT license](https://opensource.org/licenses/MIT).
