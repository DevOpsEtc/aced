#!/usr/bin/env bash

#####################################################
##  filename:   os_misc.sh                         ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    OS one-off tasks                   ##
##  date:       04/24/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

os_misc() {
  echo -e "\n$white \b****  OS: Misc Install Tasks  ****"

  echo -e "\n$green \bRemote: setting OS hostname => $os_hostname... $reset \n"
  ssh -t $ssh_alias " \
    sudo sed -i '/127.0.0.1/ s/^.*$/127.0.0.1 $os_hostname/' /etc/hosts \
    && sudo sed -i 's/^.*$/$os_hostname/' /etc/hostname \
    && sudo hostname $os_hostname"
  cmd_check

  echo -e "\n$green \bRemote: creating symlink from /var/logs => ~/log..."
  ssh $ssh_alias "sudo ln -s /var/log/ ~/logs"
  cmd_check
}
