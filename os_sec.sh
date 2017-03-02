#!/usr/bin/env bash

####################################################
##  filename:   os_sec.sh                         ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    Server Security Hardening         ##
##  date:       03/02/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

######################################################
####  ssh daemon config: /etc/ssh/sshd_config  #######
######################################################

# ssh aws 'cat /etc/ssh/sshd_config'

# Port 222                :port to listen on; keep logs cleaner
# LogLevel VERBOSE        :log failed login attempts to /var/log/auth.log
# PermitRootLogin no      :disable root ssh access
# ClientAliveInterval 300 :idle log out timeout interval; 300 secs = 5 minutes
# ClientAliveCountMax 0   :
# AllowUsers              : user whitelist; deny all others
# UsePAM no
# DebianBanner no         :suppress linux version banner
# MaxAuthTries 1          :max login attempts
# MaxSessions 2           :max simultaneous connections

echo -e "\n$aed_grn \bLocking down ssh config..."
ssh aws "sudo sed -i \
  -e 's/Port 22/Port 222/' \
  -e 's/LogLevel INFO/LogLevel VERBOSE/' \
  -e 's/PermitRootLogin prohibit-password/PermitRootLogin no/' \
  -e 's/X11Forwarding yes/X11Forwarding no/' \
  -e 's/UsePAM yes/UsePAM no/' \
  -e '$ a\ClientAliveInterval 300' \
  -e '$ a\ClientAliveCountMax 0' \
  -e '$ a\AllowUsers $aed_os_user ubuntu' \
  -e '$ a\DebianBanner no' \
  -e '$ a\MaxAuthTries 1' \
  -e '$ a\MaxSessions 2' \
  -e '$ a\DebianBanner no' \
	/etc/ssh/sshd_config"

# restart ssh service
echo -e "\n$aed_grn \bRestarting ssh daemon..."
ssh aws 'sudo service ssh restart'

#############################################################
#### update ssh connection alias ############################
#############################################################

echo -e "\n$aed_grn \bUpdating localhost SSH connection alias..."
sed -i \
  -e "s/User ubuntu/User $aed_os_user/" \
  -e 's/Port 22/Port 222/' \
  $aed_ssh_cfg

#############################################################
####  lock down users  ######################################
#############################################################

# lock root account; unlock: su - && passwd
echo -e "\n$aed_grn \bLocking root account..."
sudo passwd -l root

# lock default ubuntu account; unlock: passwd -u ubuntu
echo -e "\n$aed_grn \bLocking ubuntu account..."
sudo passwd -l ubuntu



# iptables
#
# 80  tcp
# 443 tcp
# 222 tcp
# fail2ban
