#!/usr/bin/env bash

#####################################################
##  filename:   app.sh                             ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    install and config apps            ##
##  date:       04/03/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

os_app() {
  echo -e "$white
  \b\b###############################################
  \b\b###  OS: App Update/Upgrade/Install/config  ###
  \b\b###############################################"
  os_app_install  # invoke function to update & install apps
  os_app_config   # invoke function to config installed apps
  os_app_misc
}

os_app_install() {
  # kill package manager yes prompts
  DEBIAN_FRONTEND=noninteractive

  echo -e "\n$green \bUpdating package list... \n$blue"
  ssh $ssh_alias "sudo apt-get update"
  exit_code_check

  echo -e "\n$green \bUpgrading installed packages & dependencies... \n$blue"
  ssh $ssh_alias "sudo apt-get -o Dpkg::Options::='--force-confold' \
  dist-upgrade -q -y --force-yes"
  exit_code_check


  # install nvm

  # array of app names to install
  app_install=(
    fail2ban
    htop
    tree
  )
  # node
  # ghost
  # nginx

  for i in "${app_install[@]}"; do
    echo -e "\n$green \bInstalling app: $i... \n$blue"
    ssh $ssh_alias "sudo apt-get -y install $i"
    exit_code_check
  done
}

os_app_config() {
  :
  # reboot to test everything coming up ok
  # monitoring
  # logs
  # git remote repo
  # git push to remote repo

  # mkdir -p ~/src/blog/blog.git
  # cd ~/src/blog/blog.git
  # git init --bare

  # post receive hooks
  # see archived bus app
  # sudo systemctl restart systemd-logind.service
  # autorenewing cert
  # log rotation
}

os_app_misc() {
  echo -e "\n$green \bUpdating hostname in /etc/hosts... \n$blue"
  ssh -t $ssh_alias "sudo sed -i \
    '/127.0.0.1/ s/^.*$/127.0.0.1 $ec2_hostname/' /etc/hosts"
  exit_code_check

  echo -e "\n$green \bUpdating hostname in /etc/hostname... \n$blue"
  ssh -t $ssh_alias "sudo sed -i 's/^.*$/$ec2_hostname/' /etc/hostname"
  exit_code_check

  echo -e "\n$green \bUpdating hostname via $ hostname..."
  ssh $ssh_alias "sudo hostname $ec2_hostname"
  exit_code_check

  echo -e "\n$green \bCreating symlink to logs..."
  ssh $ssh_alias "ln -s /var/log/ ~/logs"
  exit_code_check
}
