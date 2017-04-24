#!/usr/bin/env bash

#####################################################
##  filename:   os_sec.sh                          ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    server security hardening          ##
##  date:       04/24/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

os_sec() {
  echo -e "\n$white \b****  OS: Security-Related Tasks  ****"
  os_user_create           # check existing/create new; add group
  os_hard_sshd             # lockdown SSH config
  ec2_rule_add port_update # revoke/authorize inbound rules
  ssh_alias_create update  # pass changes in alias connection values
  os_ip_tables             # firewall setup
  os_hard_misc             # memory, network, misc OS
}

os_user_create() {
  # SSH without PAM: http://arlimus.github.io/articles/usepam
  echo -e "\n$green \bRemote: creating new user: $os_user... "
  echo $blue; ssh $ssh_alias "sudo adduser --disabled-password --gecos '' \
    $os_user"
  cmd_check

  echo -e "\n$yellow \bCreate password for new user: $os_user \
  \n\n$gray * Store in secure location, e.g. password manager app!"

  read -rsp $'\n'"$yellow""Enter password: " os_user_pass

  echo -e "\n\n$green \bRemote: setting password for $os_user..."
  ssh $ssh_alias "echo $os_user:$os_user_pass | sudo chpasswd"
  cmd_check

  echo -e "\n$green \bRemote: adding $os_user to sudo group"
  ssh $ssh_alias "sudo usermod -aG sudo $os_user"
  cmd_check

  echo -e "\n$green \bRemote: allowing password-less sudo for $os_user \
    \b\b\b\b(temporary)... "
  echo "$os_user ALL=(ALL) NOPASSWD:ALL" \
    | ssh $ssh_alias "sudo tee -a /etc/sudoers.d/$aced_nm_title-users > \
      /dev/null"
  cmd_check

  echo -e "\n$green \bRemote: pushing public key => ~/.ssh/authorized_keys"
  cat $aced_keys/$ssh_key_public \
    | ssh $ssh_alias "sudo mkdir -p /home/$os_user/.ssh \
    && sudo tee /home/$os_user/.ssh/authorized_keys > /dev/null"
  cmd_check

  echo -e "\n$green \bRemote: setting ownership & file permissions: $blue \
    \n\nOwner:\t$os_user \
    \nPerms:\t~/.ssh => 700 \
    \nPerms:\t~/.ssh/authorized_keys => 600"
  ssh $ssh_alias " \
    sudo chown -R $os_user:$os_user /home/$os_user/.ssh \
    && sudo chmod u=rwx,go= /home/$os_user/.ssh \
    && sudo chmod u=rw,go= /home/$os_user/.ssh/authorized_keys"
  cmd_check
} # end func: os_user_create

os_hard_sshd() {
  echo -e "\n$green \bRemote: hardening SSH server... $reset \n"
  ssh -t $ssh_alias "sudo sed -i \
    -e '/AllowTcpForwarding/ s/^.*$/AllowTcpForwarding no/g' \
    -e '/LogLevel/ s/^.*$/LogLevel VERBOSE/g' \
    -e '/LoginGraceTime/ s/^.*$/LoginGraceTime 30/g' \
    -e '/PasswordAuthentication/ s/^.*$/PasswordAuthentication no/g' \
    -e '/PermitRootLogin/ s/^.*$/PermitRootLogin no/g' \
    -e '/Port/ s/^.*$/Port $os_ssh_port/g' \
    -e '/Protocol/ s/^.*$/Protocol 2/g' \
    -e '/PubkeyAuthentication/ s/^.*$/PubkeyAuthentication yes/g' \
    -e '/UsePAM/ s/^.*$/UsePAM no/g' \
    -e '/X11Forwarding/ s/^.*$/X11Forwarding no/g' \
    -e '$ a\AllowUsers $os_user' \
    -e '$ a\ClientAliveInterval 300' \
    -e '$ a\ClientAliveCountMax 0' \
    -e '$ a\DebianBanner no' \
    -e '$ a\MaxAuthTries 2' \
    /etc/ssh/sshd_config"
  cmd_check

  echo -e "\n$green \bRemote: restarting SSH daemon... $reset \n"
  ssh -t $ssh_alias "sudo service ssh restart"
  cmd_check

  echo -e "\n$green \bRemote: waiting on SSH port to accept connections... "
  ec2_eip_fetch silent # fetch current EIP
  aws_waiter SSH silent &
  activity_show
} # end func: os_hard_sshd

os_ip_tables() {
  echo -e "\n$green \bRemote: creating directory for IPTables rules..."
  ssh $ssh_alias "sudo mkdir /etc/iptables"
  cmd_check

  echo -e "\n$green \bRemote: pushing IPTables rules => \
    \b\b\b\b\b /etc/iptables/rules.v4... "
  echo $blue; cat ./build/rules.v4 | sed "s/ssh_port/$os_ssh_port/g" \
    | ssh $ssh_alias "sudo tee /etc/iptables/rules.v4 > /dev/null"
  cmd_check

  # ssh -n backgrounds remote command and gives prompt back to script
  echo -e "\n$green \bRemote: restoring IPTables rules... "
  echo $blue; ssh -n $ssh_alias " \
    sudo iptables-restore < /etc/iptables/rules.v4 \
    && sudo iptables -S"
  cmd_check
}

os_hard_misc() {
  echo -e "\n$green \bRemote: shared memory hardening... "
  echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" \
    | ssh $ssh_alias "sudo tee -a /etc/fstab > /dev/null"
  cmd_check
}

os_hard_act() {
  # password & ssh login; unlock: sudo usermod -e -1 $os_user_def
  echo -e "\n$green \bRemote: locking default account: $os_user_def... "
  $blue; ssh -t $ssh_alias "sudo usermod -e 1 $os_user_def"
  cmd_check

  echo -e "\n$green \bRemote: removing password-less sudo for $os_user..."
  rm -rf /etc/sudoers.d/$aced_nm_title-users &>/dev/null
  cmd_check
}
