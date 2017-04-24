#!/usr/bin/env bash

#####################################################
##  filename:   misc.sh                            ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    misc ACED helper tasks             ##
##  date:       04/24/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

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

notify() {
  if [[ "$1" == "instance" ]]; then
    echo -e "\n$red \b*** Running multiple EC2 instances will exceed \
      \b\b\b\b\b\bfree-tier limit: 750 hours/month ***"
  elif [[ "$1" == "eip_gist" ]]; then
    echo -e "\n$yellow \b*** Your instance's EIP will be disassociated \
    \b\b\b\b\b & released... but a new one will be allocated & associated ***"
  elif [[ "$1" == "eip" ]]; then
    ec2_eip_fetch silent
    echo -e "\n$yellow \b**** $os_fqdn not reachable until after YOU update \
      \b\b\b\b\b\b\b its DNS host records! **** "
    echo -e "$gray
    1. Fetch your instance's new IP address: $ aced --eip
    2. Go to your domain registrar
    3. Create a new DNS host record:
        Type: A Record
        Host: @
        Value: $ec2_ip_last
        TTL: 5 min (change to automatic or highest after propagation)
    4. Wait for DNS propagation
    5. Check status: http://viewdns.info/propagation
    6. During interim, use IP address: http://$ec2_ip_last"
  fi
}

argument_check() {
  # exit ACED with error if no arguments passed when invoking function
  [[ "$#" -eq 0 ]] || { echo -e "$red\nNo Arguments Passed! $reset"; exit 1; }
}

aced_cfg_push() {
  argument_check
  for i in "$@"; do
    echo -e "\n$green \bPushing $blue \b$i: ${!i}$green => ACED config..."

    if [ $i == "aced_ok" ]; then
      sed -i '' "/$i/ s/false/true /" $aced_app/config.sh
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
      y|Y ) echo; break ;;
      n|N ) echo; break ;;
      *   ) echo; echo -e "\n$red \bInvalid Input! $reset" ;;
    esac
  done
}

lip_fetch() {
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

known_host_add() {
  if [ "$1" == "update" ]; then
    port=$os_ssh_port
    echo -e "$green \bLocalhost: removing prior EIP from known_hosts... "
    echo $blue; ssh-keygen -R [$ec2_ip_last]:$port
    cmd_check
  else
    port=22
  fi

  echo -e "\n$green \bRemote: waiting on SSH port to accept connections... "
  aws_waiter SSH &
  activity_show

  # prevents host key verification notice; you initiated it, so legit
  echo -e "\n$green \bLocalhost: forcing EC2 host (EIP) => known_hosts... "
  ssh -n -o StrictHostKeyChecking=no $ssh_alias "exit" &>/dev/null
  cmd_check
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
