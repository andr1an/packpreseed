#!/bin/bash

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
cd /tmp

timeout 1m wget "http://apt.puppetlabs.com/puppetlabs-release-jessie.deb" \
  && dpkg -i puppetlabs-release-jessie.deb \
  || touch /root/puppet_failed

timeout 1m apt-get update || exit 0

if [[ ! -f /root/puppet_failed ]]; then
  timeout 4m apt-get -y install puppet \
    || { touch /root/puppet_failed; exit 0; }
  apt-get clean
fi
