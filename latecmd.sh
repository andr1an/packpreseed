#!/bin/bash

PUPPETLABS_DEB='puppetlabs-release-jessie.deb'

######
### SSH server config

# Disable root login
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Disable UseDNS
grep '^UseDNS' /etc/ssh/sshd_config \
  && sed -i 's/^UseDNS.*/UseDNS no/' /etc/ssh/sshd_config \
  || echo 'UseDNS no' >> /etc/ssh/sshd_config

######
### Setting default editor
/usr/bin/update-alternatives --set editor /usr/bin/vim.basic

######
### Puppet 3 installation

install_puppet() {
  cd /tmp
  timeout 1m wget "http://apt.puppetlabs.com/${PUPPETLABS_DEB}" || return 1
  dpkg -i "$PUPPETLABS_DEB" || return 1
  rm -f "$PUPPETLABS_DEB"

  export DEBIAN_FRONTEND=noninteractive

  sed -i 's/^deb cdrom.*/#&/' /etc/apt/sources.list

  timeout 1m apt-get update || return 1
  timeout 4m apt-get -y --force-yes install puppet || return 1
  apt-get clean

  return 0
}

install_puppet || touch /root/puppet_failed

exit 0
