#!/usr/bin/env bash

#####################################################
##  filename:   misc.sh                            ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    misc ACED helper tasks             ##
##  date:       09/10/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

aced_cfg_push() {
  argument_check
  for i in "$@"; do
    echo -e "\n$green \bPushing $blue \b$i: ${!i}$green => ACED config..."
    if [ $i == "aced_ok" ] || [ $i == "os_cert_issued" ]; then
      sed -i '' "/$i/ s/false/true /" $aced_app/config.sh
      if [ "$os_cert_issued" == true ]; then
        sed -i '' "/$i/ s/true/false/" $aced_app/config.sh
      fi
      cmd_check
      break
    elif [ $i == "ec2_ip" ] || [ $i == "localhost_ip" ]; then
      # pad leading zeros as needed; keep alignment in config pretty
      ip_cooked="$(printf '%03d.%03d.%03d.%03d' ${!i//./ })"

      if [ $i == "localhost_ip" ]; then
        # apply 24-bit netmask (subnet hosts: .001 to .254)
        # ip_masked_24=$(echo $ip_raw | sed 's/\.[0-9]\{1,3\}$/\.000\/24/')
        # apply 32-bit netmask to padded IP
        ip_cooked=$ip_cooked/32
      fi

      # escape all dot octet separators & any netmask slash
      ip_cooked=$(echo $ip_cooked | sed -e 's/\./\\./g' -e 's_\/_\\\/_')

      # update localhost_ip value with processed IP; escape double quotes
      sed -i '' "/$i/ s/\".*\"/\"$ip_cooked\"/" $aced_app/config.sh
      cmd_check
      break
    fi

    # match line; substitute characters inside quotes with argument value
    sed -i '' "/$i/ s/\".*\"/\"${!i}\"/" $aced_app/config.sh
    cmd_check
  done
}

activity_show() {
  ##########################################################
  ##  Activity indicator for longer running processes     ##
  ##  Note: process must be in parent shell, not child    ##
  ##  e.g. $ sleep 10 & activity_show  # "&" sends to bg  ##
  ##########################################################

  echo $cur_hide
  while kill -0 $! &>/dev/null; do
    act_cur_frame=$(( (act_cur_frame+1) %4 ))
    printf "\b${blue}${act_frames:$act_cur_frame:1}"
    sleep .1
  done
  echo $cur_show && echo $cur_show # yes, twice is right
}

argument_check() {
  # exit ACED with error if no arguments passed when invoking function
  [[ "$#" -eq 0 ]] || { echo -e "$red\nNo Arguments Passed! $reset"; exit 1; }
}

cert_get() {
  ###################################################
  ####  Request/revoke/restore web certificates  ####
  ###################################################
  [[ $1 == "redo" ]] && os_cert_issued=false

  if [ "$os_cert_issued" == true ]; then
    echo -e "$green \bCertbot: fetching certificate info... "
    echo $blue; ssh $ssh_alias "sudo certbot certificates"
    decision_response Revoke web certificates?
    if [[ "$response" =~ [yY] ]]; then
      echo -e "\n$green \bCertbot: revoking web certificates... "
      echo $blue; ssh $ssh_alias " \
        sudo certbot revoke \
          --cert-path /etc/letsencrypt/live/$os_fqdn/fullchain.pem \
          --key-path /etc/letsencrypt/live/$os_fqdn/privkey.pem \
          && sudo rm -rf /etc/letsencrypt"
      cmd_check
      if find $aced_certs -mindepth 1 | read; then
        echo -e "\n$green \bBacking up web certs to: \
          \n\n$blue \b$aced_backups/certs/certs_"$(date +%m-%d-%Y_%H-%M)"... "
        mv $aced_certs $aced_backups/certs/certs_$(date +%m-%d-%Y_%H-%M)
        cmd_check
      fi

      echo -e "\n$green \bChecking for & removing custom certbot cron job..."
      ssh $ssh_alias " \
        [[ -f /etc/cron.d/cert_renew ]] && sudo rm -f /etc/cron.d/cert_renew"
      cmd_check

      aced_cfg_push os_cert_issued

      decision_response Request new web certificates?
      if [[ "$response" =~ [yY] ]]; then
        cert_get
      fi
    fi
  else
    if [ "$1" == "redo" ]; then
      echo -e "\n$green \bRemote: restoring your web certificates... $reset\n"
      rsync -rvl --rsync-path="sudo rsync" $aced_certs/ $ssh_alias:/etc/letsencrypt/
      cmd_check
    else
      echo -e "\n$green \bCertbot: requesting web certificates from \
        \b\b\b\b\b\b\b\bLet's Encrypt... "
      echo $blue; ssh $ssh_alias "sudo certbot certonly --webroot \
        -w $os_www_live/public -d $os_fqdn,www.$os_fqdn \
        -w $os_www_dev/public -d $os_fqdn_dev \
        --email $os_user_email --agree-tos --no-eff-email"
      cmd_check
    fi

    echo -e "\n$green \bRemote: creating 2048-bit DHE key to secure \
      \b\b\b\b\b\bcommunication with HTTP server & Let's Encrypt CA..."
    echo $blue; ssh $ssh_alias " \
      sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048"
    cmd_check

    sites=("dev" "live")

    for i in "${sites[@]}"; do
      [[ "$i" == "live" ]] && fqdn=$os_fqdn
      [[ "$i" == "dev" ]] && fqdn=$os_fqdn_dev

      echo -e "\n$green \bRemote: Updating server block with TLS \
        \b\b\b\b\b\b\b\bdirectives for $fqdn..."
      # e1: kill pre-cert block; ec2: uncomment post-cert block; e3: kill headers
      ssh $ssh_alias " \
        sudo sed -i \
          -e '/pre-cert/,/pre-cert/d' \
          -e '/post-cert/,/post-cert/{s/^# //g}' \
          -e '/post-cert/d' \
        /etc/nginx/sites-available/$fqdn"
      cmd_check
    done

    echo -e "\n$green \bRemote: checking Nginx config & restarting service... \
      \n$reset"
    ssh $ssh_alias "sudo nginx -t && sudo service nginx restart"
    cmd_check

    if [ "$1" != "redo" ]; then
      echo -e "\n$green \bRemote: backing up certs for $aced_nm restores \
        \n\n$blue \b$aced_certs "
      [[ -d $aced_certs ]] || mkdir $aced_certs
      rsync -azhe ssh --rsync-path="sudo rsync" \
        $ssh_alias:/etc/letsencrypt/{archive,live,renewal} $aced_certs
      cmd_check
    fi

    echo -e "\n$green \bLocalhost: removing certificate cruft... "
    ssh $ssh_alias " \sudo rm -rf \
      /var/www/devopsetc.com/{live/public/.well-known,dev/public/.well-known} \
      && sudo rm -f /etc/cron.d/cerbot"
    cmd_check

    echo -e "\n$green \bRemote: creating cron job for certbot renewal... "
    str_1='52 0,12 * * * root /usr/bin/certbot renew --deploy-hook'
    str_2='"systemctl reload nginx"'
    echo -e "$str_1 $str_2 | /usr/bin/logger -t cert_renew_cron" \
      | ssh $ssh_alias "sudo tee /etc/cron.d/cert_renew &>/dev/null"

    aced_cfg_push os_cert_issued

    echo -e "\n$green \bOpening www.$os_fqdn_title... $reset"
    open https://www.$fqdn
    cmd_check
  fi
} # end func: cert_get

cmd_check() {
  exit_code=$?
  if [ $exit_code -eq 0 ]; then
    echo -e "\n$blue \b$icon_pass Success! $reset"
  else
    echo -e "\n$red \b$icon_fail Last Command Failed: exit code $exit_code \
    $reset"
    exit 1
  fi
}

decision_response() {
  ###################################################
  ####  Display decision/prompt for response     ####
  ####  e.g: $ decision_response Are you tired?  ####
  ###################################################
  argument_check

  # concatenate parameter
  decision=$*

  while true; do
    read -n 1 -p $'\n'"$yellow""$decision (Y/N)  " response
    case $response in
      y|Y ) echo $reset; break ;;
      n|N ) echo $reset; break ;;
      *   ) echo; echo -e "\n$red \bInvalid Input! $reset" ;;
    esac
  done
}

ip_fetch() {
  if [ "$1" == "last" ] || [ "$1" == "match" ] || [ "$1" == "ls" ]; then
    # strip any leading zeros from IP octets to prevent potential errors
    lip_last=$(echo $localhost_ip \
      | awk -F'[.]' '{a=$1+0; b=$2+0; c=$3+0; d=$4+0; \
      print a"."b"."c"."d"/32"}')
    [[ "$1" == "ls" ]] && { echo -e "\n$blue \b$lip_last"; return; }
    [[ "$1" != "match" ]] && return # bail now if matching args passed
  fi

  echo -e "\n$green \bFetching public IP address for localhost ..."
  localhost_ip=$(curl -s http://checkip.amazonaws.com/)
  cmd_check
}

known_host_add() {
  port=22
  if [ "$1" == "update" ]; then
    port=$os_ssh_port
    echo -e "\n$green \bLocalhost: removing prior EIP from known_hosts... \
      $reset\n"
    echo $blue; ssh-keygen -R [$ec2_ip_last]:$port
    cmd_check
  elif [ "$1" == "redo" ]; then
    echo -e "\n$green \bLocalhost: removing prior EIP from known_hosts... \
      $reset\n"
    ssh-keygen -R $ec2_ip_last
  fi

  echo -e "\n$green \bRemote: waiting on SSH port to accept connections... "
  aws_waiter SSH &
  activity_show

  # prevents host key verification notice; you initiated it, so legit
  echo -e "$green \bLocalhost: forcing EC2 host (EIP) => known_hosts... "
  ssh -n -o StrictHostKeyChecking=no $ssh_alias "exit" &>/dev/null
  cmd_check
}

notify() {
  if [[ "$1" == "instance" ]]; then
    echo -e "\n$red \b*** Running multiple EC2 instances will exceed \
      \b\b\b\b\b\bfree-tier limit: 750 hours/month *** $reset"
  elif [[ "$1" == "eip_gist" ]]; then
    echo -e "\n$yellow \bInstance EIP will be disassociated, but not \
    \b\b\b\breleased. Depending upon how long the EIP remains \
    \b\b\b\bdisassociated you may see a charge on your AWS invoice for \
    \b\b\b\b\$0.005/per hour. Starting ACED will reassociate the EIP. $reset"
  elif [[ "$1" == "eip" ]]; then
    ec2_eip_fetch silent
    echo -e "\n$yellow \b**** $os_fqdn not reachable until after YOU update \
      \b\b\b\b\b\b\b its DNS host records! ****  $reset"
    echo -e "$gray
    1. Fetch your instance's new IP address: $ aced --eip
    2. Go to your domain registrar
    3. Create 3 DNS host records:
        Type: A Record
        Host: (@, www, dev)
        Value: $ec2_ip_last
        TTL: 5 min (change to 60 min after propagation)
    4. Wait on DNS propagation: \
      \b\b\b\b\b\bhttp://viewdns.info/propagation/?domain=$os_fqdn"
  elif [[ "$1" == "cert" ]]; then
    echo -e "\n$yellow \b**** Final Step: request TLS web certificate from \
      \b\b\b\b\b\bLet's Encrypt... $ aced --tls **** $reset"
  fi
}

os_admin() {
  if [ $1 == "rules" ]; then
    echo $blue; ssh -t $ssh_alias "sudo iptables -L -nv --line-numbers"
  elif [ $1 == "bans" ]; then
    echo $blue; ssh -t $ssh_alias "sudo iptables -L -n --line-numbers \
      | grep 'Chain f2b\|REJECT'"
  elif [ $1 == "jails" ]; then
    echo $blue; ssh -t $ssh_alias "jails=(\$(sudo fail2ban-client status \
      | awk '/Jail list/ {gsub(/,/,\"\");for(i=4;i<=NF;++i)print \$i}')) \
    && for j in \${jails[@]}; do echo; sudo fail2ban-client status \$j; done"
  elif [ $1 == "certs" ]; then
    echo -e "\n$green \bCertbot: fetching certificate info... "
    echo $blue; ssh -t $ssh_alias "sudo certbot certificates"
  elif [ $1 == "dns" ]; then
    echo $blue; dig any $os_fqdn
  elif [ $1 == "drops" ]; then
    echo $blue; ssh -t $ssh_alias " \
      sudo cat /var/log/syslog | awk '/IPT_DROP/ {print \$0,\"\n\"}'"
  elif [ $1 == "services" ]; then
    echo $blue; ssh -t $ssh_alias " \
      systemctl status nginx sshd fail2ban netfilter-persistent --no-page"
  elif [ $1 == "net_services" ]; then
    echo $blue; ssh -t $ssh_alias "sudo netstat -tulpn"
  elif [ $1 == "processes" ]; then
    echo $blue; ssh $ssh_alias " \
      ps aux | grep '[U]SER\|[n]ginx\|[s]shd\|[f]ail2ban'"
  elif [ $1 == "ports" ]; then
    echo $blue; ssh -t $ssh_alias "netstat -nlt | grep ':80\|:443\|:$os_ssh_port'"
  elif [ $1 == "updates" ]; then
    echo -e "\n$green \bRemote: Updating package lists... $blue\n"
    ssh -t $ssh_alias "sudo apt update -q 2> /dev/null"
    updates=$(ssh $ssh_alias "apt list --upgradable 2> /dev/null")
    if [ "$updates" != "Listing..." ]; then
      echo -e "\n$green \bRemote: Checking for app updates... $blue\n"
      ssh $ssh_alias "apt list --upgradable 2> /dev/null"
      decision_response Upgrade all packages?
      if [[ "$response" =~ [yY] ]]; then
        echo $blue; ssh -t $ssh_alias " \
          sudo DEBIAN_FRONTEND=noninteractive apt-get -qy \
            -o DPkg::options::=\"--force-confdef\" \
            -o DPkg::options::=\"--force-confold\" \
          dist-upgrade \
            --allow-downgrades \
            --allow-remove-essential \
            --allow-change-held-packages"
      fi
    fi
  elif [ $1 == "logs" ]; then
    logs=(
      "syslog"
      "auth.log"
      "fail2ban.log"
      "nginx/error.log"
      "nginx/access.log"
    )
    for l in "${logs[@]}"; do
    	echo -e "\n$green \bRemote: fetching tailed log: /var/log/$l... "
    	echo $blue; ssh -t $ssh_alias "sudo tail /var/log/$l"
    done
  fi
  cmd_check
  read -n 1 -s -p $'\n'"$yellow""Press any key to continue "; clear
} # end func: os_admin

ssh_alias_create() {
  if [ "$1" == "update" ]; then
    echo -e "\n$green \bUpdating SSH connection alias: $ssh_alias..."
    # escape all dots between IP octets
    ip_escaped=$(echo $ec2_ip | sed -e 's/\./\\./g')
    # match pattern; do substitutes on N lines below match
    sed -i '' \
      -e "/Host $ssh_alias/ { N; s/HostName .*/HostName $ip_escaped/; }" \
      -e "/HostName $ip_escaped/ { N; s/User .*/User $os_user/; }" \
      -e "/User $os_user/ { N; s/Port .*/Port $os_ssh_port/; }" \
      ~/.ssh/config
    cmd_check
    return
  fi

  if [ -d $ssh_config ]; then
    echo -e "\n$green \bBacking up SSH config to: \
      \n\n$blue \b$aced_backups/ssh/ssh_"$(date +%m-%d-%Y_%H-%M)"... "
    rsync -a --exclude='.*' /$ssh_config/ \
      /$aced_backups/ssh/ssh_"$(date +%m-%d-%Y_%H-%M)"
    cmd_check
  fi

  echo -e "\n$green \bChecking for existing $aced_nm SSH connection alias..."
  if grep -qw "Host $ssh_alias" ~/.ssh/config; then
    # delete line prior to match via hold space
    sed -i '' -n "/## $ssh_alias ##/{x;d;};1h;1!{x;p;};\${x;p;}" ~/.ssh/config
    # delete lines between matching patterns
    sed -i '' "/## $ssh_alias ##/,/## \/$ssh_alias ##/d" ~/.ssh/config
    cmd_check

    [[ "$1" == "remove" ]] && return
  else
    echo -e "\n$blue \bNo ACED SSH connection alias found!"
  fi

  echo -e "\n$green \bCreating SSH connection alias: $ssh_alias..."
  echo -e " \
    \n## $ssh_alias ############################ \
    \nHost $ssh_alias \
    \n  HostName $ec2_ip \
    \n  User $os_user_def \
    \n  Port 22 \
    \n  IdentityFile $aced_keys/$ssh_key_private \
    \n## /$ssh_alias ###########################" \
    >> ~/.ssh/config
  cmd_check

  echo -e "\n$green \bSetting file permissions on ~/.ssh/config to 600..."
  chmod u=rw,go= ~/.ssh/config
  cmd_check
} # end func: ssh_alias_create

sudo_pass() {
  echo -e "\n$green \bRemote: toggling password-less sudo for $os_user... \
    $reset \n"
  ssh -t $ssh_alias " \
    sudo sed -i '/$os_user/ s/^\s*#//; t; /$os_user/ s/^\s*/# /' \
      /etc/sudoers.d/$aced_nm_title-users && sudo -k"

  sudo_test=$(ssh aced "sudo date &>/dev/null") # see if sudo fails without -t
  [[ $? == 0 ]] && ss="on" || ss="off" # check prior command for fail
  echo -e "\n$blue \bPassword-less sudo $ss! $reset"

  [[ "$1" == "menu" ]] \
    && read -n 1 -s -p $'\n'"$yellow""Press any key to continue "; clear
}

web_mm() {
  echo -e "\n$green \b$os_fqdn_title: toggling maintenance mode... $reset\n"
  ssh -t $ssh_alias " \
    sudo sed -i '/return 503/ s/^\s*#/ /; t; /return 503/ s/^\s*/  # /' \
    /etc/nginx/sites-available/devopsetc.com \
    && sudo service nginx reload"

  aws_waiter HTTPS

  # fetch current HTTP status
  http_status=$(curl -s -o /dev/null -I -w "%{http_code}" https://www.$os_fqdn)
	[[ $http_status == "503" ]] && mm="on" || mm="off"
  echo -e "\n$blue \bMaintenance mode $mm! $reset"

  [[ "$1" == "menu" ]] \
    && read -n 1 -s -p $'\n'"$yellow""Press any key to continue "; clear
}

uninstall() {
  echo -e "\n$white
  \b\b#########################################
  \b\b########  ACED Uninstall  ###############
  \b\b#########################################"

  # invoke func: display decision/capture response
  decision_response Really uninstall $aced_nm?

  # bail from uninstall if responds with "n" or "N"
  [[ "$response" =~ [nN] ]] && { echo -e "$red\n\nUninstall Stopped!"; exit; }

  echo -e "\n$green \bRemoving alias..."
  sed -i '' "/alias $ec2_tag=.*/d" ~/.bash_profile
  cmd_check

  echo -e "\n$green \bRemoving AWS configuration..."
  rm -rf $aws_config &>/dev/null
  cmd_check

  ssh_alias_create remove # invoke func: remove ssh connection alias

  if ssh-add -L | grep -q "$aced_keys/$ssh_key_private"; then
    echo -e "\n$green \bRemoving $aced_nm private key from localhost SSH \
    \b\bagent... \n"
    ssh-add -d $aced_keys/$ssh_key_private &>/dev/null
    cmd_check
  fi

  # remove localhost keypair

  decision_response Remove $aced_nm config directory?
  if [[ "$response" =~ [yY] ]]; then
    echo -e "\n$green \bRemoving $aced_nm config directory..."
    rm -rf $aced_config &>/dev/null
    cmd_check
  else
    aced_root_rm=false
  fi

  decision_response Remove $aced_nm data directory & repo?
  if [[ "$response" =~ [yY] ]]; then
    echo -e "\n$green \bRemoving $aced_nm data directory & repo..."
    rm -rf $aced_src &>/dev/null
    cmd_check
  else
    aced_root_rm=false
  fi

  if [ $aced_root_rm != false ]; then
    rm -rf $aced_root &>/dev/null
    cmd_check
  else
    echo -e "\n$green \bRemoving $aced_nm app directory..."
    rm -rf $aced_app &>/dev/null
    cmd_check

    echo -e "\n$yellow \bHere are the files you chose to keep: \n"
    find ~/aced/* -type f -maxdepth 4
  fi

  echo -e "\n$yellow \b$aced_nm uninstall complete! \
  \n\nReview AWS web console to manage your remaining IAM & EC2 resources"

  version
  echo -e "\n$blue \bThanks for trying $aced_nm!"
} # end function: uninstall
