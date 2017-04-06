#!/usr/bin/env bash

#####################################################
##  filename:   os_sec.sh                          ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    server security hardening          ##
##  date:       04/04/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

os_sec() {
  echo -e "$white
  \b\b#########################################
  \b\b###  OS: User/Sudo/Keypair/Hardening  ###
  \b\b#########################################"
  os_user_create                    # check existing/create new; add group
  harden_misc                       # memory, network, misc OS
  harden_sshd                       # lockdown SSH config
  ec2_rule_ingress_add port_update  # revoke/authorize inbound rules
  ssh_alias_create update           # pass changes in alias connection values
}

os_user_create() {
  # SSH without PAM: http://arlimus.github.io/articles/usepam
  echo -e "\n$green \bCreating new EC2 user: $os_user... \n$blue"
  ssh $ssh_alias "sudo adduser --disabled-password --gecos '' $os_user"
  exit_code_check

  echo -e "\n$yellow \bCreate a password for new EC2 user $os_user: \
  \n\n**** Store in secure location, e.g. password manager app! ****"

  read -rsp $'\n'"$yellow""Enter password: " os_user_pass

  echo -e "\n\n$green \bSetting password for $os_user..."
  ssh $ssh_alias "echo $os_user:$os_user_pass | sudo chpasswd"
  exit_code_check

  echo -e "\n$green \bAdding $os_user to sudo group (elevated \
    \b\b\b\bprivileges)... $blue"
  ssh $ssh_alias "sudo usermod -aG sudo $os_user"
  exit_code_check

  echo -e "\n$green \bCreating sudoers.d file for $os_user (NOPASSWD)..."
  echo "$os_user ALL=(ALL) NOPASSWD:ALL" \
    | ssh $ssh_alias " \
    sudo tee -a /etc/sudoers.d/$ec2_tag-users > /dev/null"
  exit_code_check

  echo -e "\n$green \bFetching $ id results for $os_user... \n$blue"
  ssh $ssh_alias "id $os_user"
  exit_code_check

  echo -e "\n$green \bPushing public key: /home/$os_user/.ssh/authorized_keys"
  cat $aced_keys/$ssh_key_public \
    | ssh $ssh_alias " \
    sudo mkdir -p /home/$os_user/.ssh \
    && sudo tee /home/$os_user/.ssh/authorized_keys > /dev/null"
  exit_code_check

  echo -e "\n$green \bSetting file ownership: \
    \b\b\b\b/home/$os_user/.ssh => $os_user:$os_user..."
  ssh $ssh_alias "sudo chown -R $os_user:$os_user /home/$os_user/.ssh"
  exit_code_check

  echo -e "\n$green \bSetting file permissions: $os_user/.ssh => 700..."
  ssh $ssh_alias "sudo chmod u=rwx,go-rwx /home/$os_user/.ssh"
  exit_code_check

  echo -e "\n$green \bSetting file permissions: $os_user/.ssh/authorized_keys \
    \b\b\b\b=> 600..."
  ssh $ssh_alias "sudo chmod u=rw,go-rwx /home/$os_user/.ssh/authorized_keys"
  exit_code_check
}

harden_misc() {
  echo -e "\n$green \bHardening shared memory... "
  echo "tmpfs     /run/shm    tmpfs	defaults,noexec,nosuid	0	0" \
    | ssh $ssh_alias " \
    sudo tee -a /etc/fstab > /dev/null"
  exit_code_check
}

harden_sshd() {
  echo -e "\n$green \bHardening SSH Daemon... \n$blue"
  ssh -t $ssh_alias "sudo sed -i \
    -e '/AllowTcpForwarding/ s/^.*$/AllowTcpForwarding no/' \
    -e '/LogLevel/ s/^.*$/LogLevel VERBOSE/' \
    -e '/LoginGraceTime/ s/^.*$/LoginGraceTime 30/' \
    -e '/PasswordAuthentication/ s/^.*$/PasswordAuthentication no/' \
    -e '/PermitRootLogin/ s/^.*$/PermitRootLogin no/' \
    -e '/Port/ s/^.*$/Port $ec2_ssh_port/' \
    -e '/Protocol/ s/^.*$/Protocol 2/' \
    -e '/PubkeyAuthentication/ s/^.*$/PubkeyAuthentication yes/' \
    -e '/UsePAM/ s/^.*$/UsePAM no/' \
    -e '/X11Forwarding/ s/^.*$/X11Forwarding no/' \
    -e '$ a\AllowUsers $os_user' \
    -e '$ a\ClientAliveInterval 300' \
    -e '$ a\ClientAliveCountMax 0' \
    -e '$ a\DebianBanner no' \
    -e '$ a\MaxAuthTries 2' \
    -e '$ a\MaxSessions 2' \
    /etc/ssh/sshd_config"
  exit_code_check

  echo -e "\n$green \bRestarting SSH daemon... \n$blue"
  ssh -t $ssh_alias "sudo service ssh restart"
  exit_code_check
}

harden_accounts() {
  echo -e "\n$green \bLocking default account: $os_user_def... \n$blue"
  # password & ssh login; unlock: sudo usermod -e -1 $os_user_def
  ssh -t $ssh_alias "sudo usermod -e 1 $os_user_def"
  exit_code_check

  echo -e "\n$green \bRemoving sudoers.d file for $os_user (NOPASSWD)..."
  rm -rf /etc/sudoers.d/$ec2_tag-users &>/dev/null
  exit_code_check
}

# echo -e "\n$green \bHardening network via sysctl... "
# exit_code_check
# Disable Open DNS Recursion
# Remove Version Info
# Prevent IP Spoofing
# brute-force
# Rate-limit Incoming Port
# Port Knocking
# iptables
#
# 80  tcp
# 443 tcp
# $ec2_ssh_port tcp
# fail2ban
# reboot ec2
# auto sec updates
