# packpreseed

Script creates a personalized Debian 8 Jessie x86_64 ISO image ready for fast
KVM installation. It configures your ssh service, sudo and installs [Puppet](https://puppetlabs.com).

**WARNING!** Generated installer will ERASE ALL your virtual HDD by default!
To change this behavior, change `d-i partman*` parameters in `preseed.cfg`.

Grub bootloader will be installed on /dev/vda (fails if your first HDD path
differs); see `d-i grub-installer*` in `preseed.cfg`.

## Requirements

 - `genisoimage` tool
 - `loopfs` kernel module

## Usage

    sudo ./packpreseed.sh debian-8.4.0-amd64-netinst.iso mypreseed.iso

## License

Code released under the [MIT license](https://opensource.org/licenses/MIT).
