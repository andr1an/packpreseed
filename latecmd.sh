#!/bin/bash
#
# latecmd script for additional Debian settings
#

# Uncomment for Puppet 4.x
PUPPETLABS_DEB='puppetlabs-release-pc1-jessie.deb'
PUPPET_PACKAGE='puppet-agent'

# Uncomment for Puppet 3.8.x
#PUPPETLABS_DEB='puppetlabs-release-wheezy.deb'
#PUPPET_PACKAGE='puppet'

export DEBIAN_FRONTEND=noninteractive

install_puppet() {
  cd /tmp
  timeout 1m wget "https://apt.puppetlabs.com/${PUPPETLABS_DEB}" || return $?
  dpkg -i "$PUPPETLABS_DEB" || return $?
  timeout 1m apt-get update || return $?
  timeout 4m apt-get -y --force-yes install "$PUPPET_PACKAGE" || return $?

  apt-get clean
  return 0
}

# SSH server config - disable root login
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Disable UseDNS
grep '^UseDNS' /etc/ssh/sshd_config \
  && sed -i 's/^UseDNS.*/UseDNS no/' /etc/ssh/sshd_config \
  || echo 'UseDNS no' >> /etc/ssh/sshd_config

# Setting default editor
/usr/bin/update-alternatives --set editor /usr/bin/vim.basic

# Setting APT
sed -i 's/^deb cdrom.*/#&/' /etc/apt/sources.list
timeout 1m apt-get update
timeout 4m apt-get -y --force-yes install wget ca-certificates

# Puppet installation
install_puppet || touch /root/puppet_failed
[[ -f "/tmp/${PUPPETLABS_DEB}" ]] && rm -f "/tmp/${PUPPETLABS_DEB}"

exit 0
