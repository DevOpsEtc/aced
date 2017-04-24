#!/usr/bin/env bash

#####################################################
##  filename:   os_app.sh                          ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    install and config apps            ##
##  date:       04/22/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

os_app() {
  echo -e "\n$white \b****  OS: App-Related Install Tasks  ****"
  os_app_install  # invoke func: update native/install new apps
  os_app_config   # invoke func: config native/newly installed apps
}

os_app_install() {
  echo -e "\n$green \bRemote: updating app list & upgrading native apps & \
    \b\b\b\b\b dependencies... "
  echo $blue; ssh -t $ssh_alias " \
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qy install grub-pc \
    && sudo DEBIAN_FRONTEND=noninteractive apt-get -qy \
    -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" \
    update  \
      --allow-downgrades \
      --allow-remove-essential \
      --allow-change-held-packages \
    && sudo DEBIAN_FRONTEND=noninteractive apt-get -qy \
    -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" \
    dist-upgrade \
      --allow-downgrades \
      --allow-remove-essential \
      --allow-change-held-packages"
  cmd_check

  # array of apps to install
  app_install=(
    tree                # pretty recursive directory listing
    htop                # pretty alternative to top
    nginx               # web server to serve static site
    iptables-persistent # persist loading of IPTables rules
    fail2ban            # log monitor (brute-force attacks); trigger IPTable
  )

  # sudo apt-get remove <app>; sudo apt autoremove
  for i in "${app_install[@]}"; do
    echo -e "\n$green \bRemote: installing app: $i... "
    echo $blue; ssh -t $ssh_alias "sudo DEBIAN_FRONTEND=noninteractive \
      apt-get -qq install $i"
    cmd_check
  done
}

os_app_config() {
  :
  # nginx edit config & push server blocks
  # fail2ban edit config
}
