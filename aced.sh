#!/usr/bin/env bash

#############################################################
##  filename:   aced.sh                                    ##
##  path:       ~/src/deploy/cloud/aws/                    ##
##  purpose:    run ACED: Automated EC2 Deploy             ##
##  date:       04/06/2017                                 ##
##  symlink:    $ ln -s ~/src/deploy/cloud/aws ~/aced/app  ##
##  repo:       https://github.com/DevOpsEtc/aced          ##
##  clone path: ~/aced/app/                                ##
##  execute:    $ ~/aced/app/aced.sh                       ##
##  run:        $ aced                                     ##
##  options:    -connect -help -ip -off -on -reboot        ##
##  options:    -status -uninstall -ver                    ##
#############################################################

version() {
  echo "$blue
        ___   _____  _____ ______
       / _ \ /  __ \|  ___||  _  \\
      / /_\ \| /  \/| |__  | | | |
      |  _  || |    |  __| | | | |
      | | | || \__/\| |___ | |/ /
      \_| |_/ \____/\____/ |___/

    AWS Cloud Environment Deployment

      Version:  $aced_ver
      Released: $aced_rel
      Author:   DevOpsEtc
  $reset"
}

help() {
  echo -e "\n$yellow
    ACED Commands: \n
    $ aced                    # show ACED task menu
    $ aced -c or -connect     # access ACED instance via SSH
    $ aced -eip               # show ACED public IP address
    $ aced -lip               # show localhost public IP address
    $ aced -on or -start      # start ACED instance
    $ aced -off or -stop      # stop ACED instance
    $ aced -rb or -reboot     # reboot ACED instance
    $ aced -s or -status      # show full AWS/EC2/ACED status
    $ aced -u or -uninstall   # uninstall ACED
    $ aced -v or -version     # show ACED version information
    $ aced -? or -h or -help  # show ACED help
  $reset"
}

dashboard() {
  ##########################################################
  ####  Display EC2 health status  #########################
  ##########################################################
  ec2_state dash  # invoke function to fetch $aced_tag's current state

  case $state in
    Running	)	state_color=$green  ;;
    Stopped	)	state_color=$red	  ;;
  esac

  # get total count of instances (ignore terminated)
  ec2_ids=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values= \
    pending,running,shutting-down,stopping,stopped" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text \
    | wc -w)

  eip_ids=$(aws ec2 describe-addresses \
    --query Addresses[*].AllocationId \
    --output text \
    | wc -w)

  if [ $state == "Running" ]; then

    echo -e "\n$green \bFetching AWS system status..."
    system_status=$(aws ec2 describe-instance-status \
      --instance-ids $ec2_id \
    	--query InstanceStatuses[*].SystemStatus[].Status \
    	--output text)
    exit_code_check
    [[ $system_status == "ok" ]] && system_status="Reachable"

    echo -e "\n$green \bFetching EC2 instance status..."
    instance_status=$(aws ec2 describe-instance-status \
    	--instance-ids $ec2_id \
    	--query InstanceStatuses[*].InstanceStatus[].Status \
    	--output text)
    exit_code_check
    [[ $instance_status == "ok" ]] && instance_status="Reachable"

    # strip any leading zeros from IP octets; prevent ping resolve error
    eip_raw=$(echo $ec2_ip \
      | awk -F'[.]' '{a=$1+0; b=$2+0; c=$3+0; d=$4+0; print a"."b"."c"."d}')

    echo -e "\n$green \bFetching IP ping results..."
    ping_ip=$(ping -c 1 $eip_raw \
      | awk -F" |:" '/from/{print $1,$2,$3,$4}')
    exit_code_check

    echo -e "\n$green \bFetching FQDN ping results..."
    ping_fqdn=$(ping -c 1 $ec2_fqdn \
      | awk -F" |:" '/from/{print $1,$2,$3,$4}')
    exit_code_check

    echo -e "\n$green \bFetching system uptime..."
    uptime=$(ssh $ssh_alias "uptime -p \
      | sed -e 's/up //' -e 's/hour*/hr/' -e 's/minute*/min/'")
    exit_code_check

    echo -e "\n$green \bFetching last login..."
    last_login=$(ssh $ssh_alias "lastlog -u \$USER \
      | tail -1 | awk '{print \$4, \$5, \$6, \$7\" from \"\$3}'")
    exit_code_check

    echo -e "\n$green \bFetching processes..."
    processes=$(ssh $ssh_alias "ps -A h | wc -l") \
      && processes_user=$(ssh $ssh_alias "ps U \$USER h | wc -l")
    exit_code_check

    echo -e "\n$green \bFetching load averages..."
    top_out=$(ssh $ssh_alias "top -bn1 | head -1")
    exit_code_check

    logins=$(echo $top_out | awk '{print $6}')
    load=$(echo $top_out | awk '{print $10,$11,$12}')

    echo -e "\n$green \bFetching memory usage..."
    mem=$(ssh $ssh_alias "free -mh | tail -2 | head -1") \
      && free_mem_swp=$(ssh $ssh_alias "free -mh | tail -1")
    exit_code_check

    mem_tot=$(echo $mem | awk '{print $2}')
    mem_used=$(echo $mem | awk '{print $3}')
    mem_free=$(echo $mem | awk '{print $4}')
    mem_free_cached=$(echo $mem | awk '{print $7}')
    mem_swap_use=$(echo $free_mem_swp | awk '{print $3}')

    echo -e "\n$green \bFetching disk usage..."
    disk=$(ssh $ssh_alias "df -h --total" | tail -1)
    exit_code_check

    disk_tot=$(echo $disk | awk '{print $2}')
    disk_used=$(echo $disk | awk '{print $3}')
    disk_avail=$(echo $disk | awk '{print $4}')

    echo -e "\n$green \bChecking for package updates..."
    apt_updates=$(ssh $ssh_alias "/usr/lib/update-notifier/apt-check 2>&1")
    exit_code_check

    apt_up_reg=$(echo $apt_updates | cut -d ';' -f 1)
    apt_up_sec=$(echo $apt_updates | cut -d ';' -f 2)

    echo -e "\n$green \bChecking for package updates..."
    rel_desc=$(ssh $ssh_alias "lsb_release -d | awk '{print \$2,\$3,\$4}'") \
    && rel_code=$(ssh $ssh_alias "lsb_release -c | awk '{print \$2}'")
    exit_code_check
  else
  	msg="Not Reachable"
  	system_status="$msg"
  	instance_status="$msg"
  	ping_ip="$msg"
  	ping_fqdn="$msg"
    local ec2_ip="None"
  fi

  echo
  clear
  echo -e "\n$white \bEC2 Totals: $gray \
    \n______________________________________________________ \
    \nInstances:$blue\t$ec2_ids $gray \
    \nEIPs:$blue\t\t$eip_ids $gray \
    \n______________________________________________________
  "
  echo -e "$white \bReachability: $gray \
    \n______________________________________________________ \
    \nAWS System:$blue\t$system_status $gray\tEIP Ping: \
      \b\b\b\b\b\b\b\b$blue\t$ping_ip $gray \
    \nEC2 Instance:$blue\t$instance_status $gray\tFQDN Ping: \
      \b\b\b\b\b\b\b\b$blue\t$ping_fqdn $gray \
    \n______________________________________________________
  "
  echo -e "$white \b$aced_nm EC2 Instance: $gray \
    \n______________________________________________________ \
    \nId:$blue\t$ec2_id $gray\tTag:$blue\t$ec2_tag $gray \
    \nEIP:$blue\t$ec2_ip $gray\tState:$state_color\t$state \
    \n$gray \b______________________________________________________
  "
  echo -e "$white \b$aced_nm EC2 System: $gray \
    \n______________________________________________________ \
    \nSystem:$blue\t\t$rel_desc ($rel_code) $gray \
    \nSys Uptime:$blue\t$uptime $gray \
    \nLast Login:$blue\t$last_login $gray \
    \nUser Logins:$blue\t$logins $gray \
    \nProcesses:$blue\ttotal: $processes ($processes_user \
      \b\b\b\b\b\bowned by $os_user) $gray \
    \nLoad Avg:$blue\t$load (1,5,15 minutes) $gray \
    \nMemory:$blue\t\ttotal: $mem_tot, used: $mem_used, free: $mem_free, \
      \b\b\b\b\b\bfree cached: $mem_free_cached $gray \
    \nSwap Usage:$blue\t$mem_swap_use $gray \
    \nDisk Usage:$blue\ttotal: $disk_tot, used: $disk_used, free: \
      \b\b\b\b\b\b$disk_avail $gray \
    \nPkg Updates:$blue\tregular: $apt_up_reg, security: $apt_up_sec $gray \
    \n______________________________________________________
  "

  if [ "$1" == "menu" ]; then
    read -n 1 -s -p "$yellow""Press any key to continue "
    clear && clear
  fi
} # end function: dashboard

task_menu() {
  ##########################################################
  ####  Display AWS IAM & EC2 task menu  ###################
  ##########################################################
  # menu options array
  task_item=(
    "Start $aced_nm"
    "Stop $aced_nm"
    "Reboot $aced_nm"
    "List EC2 Group Rules"
    "Rotate EC2 IP Address"
    "Rotate IAM Access Keys"
    "Rotate Key Pair"
    "Show Full Status"
    "Connect $aced_nm"
    "QUIT"
  )

  clear
  while true; do
    # COLUMNS=20      # force select menu to display vertically
    echo -e "\n\n$white \b$aced_nm Tasks $gray \
      \n______________________________________________________"
    PS3=$'\n'"$yellow"'Choose task number: '"$reset"
    select task in "${task_item[@]}"; do
      case $task in
        "Start $aced_nm"         ) ec2_state Stopped; break ;;
        "Stop $aced_nm"          ) ec2_state Running; break ;;
        "Reboot $aced_nm"        ) ec2_reboot;        break ;;
        "List EC2 Group Rules"   ) ec2_rule_list;     break ;;
        "Rotate EC2 IP Address"  ) ec2_eip_rotate;    break ;;
        "Rotate IAM Access Keys" ) iam_keys_rotate;   break ;;
        "Rotate Key Pair"        ) ec2_keypair;       break ;;
        "Show Full Status"       ) dashboard menu;    break ;;
        "Connect $aced_nm"       ) ec2_connect;       break ;;
        "QUIT"                   ) exit 0;                  ;;
      esac
    done
  done
}

exit_code_check() {
  if [ $? -eq 0 ]; then
    echo -e "\n$blue \b$icon_pass Success! $reset"
  else
    echo -e "\n$red \b$icon_fail Failure! $reset"
    exit 1 # exit installer with error
  fi
}

argument_check() {
  # exit ACED with error if no arguments passed when invoking function
  [[ "$#" -eq 0 ]] || { echo -e "$red\nNo Arguments Passed! $reset"; exit 1; }
}

aced_config_update() {
  argument_check
  for i in "$@"; do
    echo -e "\n$green \bPushing $blue \b$i: ${!i}$green => ACED config..."

    if [ $i == "aced_installed" ]; then
      sed -i '' "/$i/ s/false/true /" $aced_app/config.sh
      exit_code_check
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
      exit_code_check
      break
    fi

    # match line; substitute characters inside quotes with argument value
    sed -i '' "/$i/ s/\".*\"/\"${!i}\"/" $aced_app/config.sh
    exit_code_check
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
  echo $cur_show
}

main() {
  ############################################################
  ####  Main ACED function: install || display task menu  ####
  ############################################################

  # bail if not run from MacOS or if aws-cli not found
  [[ $(uname) == "Darwin" ]] || { echo -e "MacOS Not Found!"; exit 1; }
  type -p aws >/dev/null || { echo -e "AWS CLI Not Found!"; exit 1; }

  # set shell option enabling alias expansion for alias test; source aliases
  shopt -s expand_aliases && . ~/.bash_profile

  # set path of ACED scripts
  cd "$(dirname $0)" || exit 1

  # sourcing scripts
  . ./config.sh     # ACED config
  . ./localhost.sh  # ACED install/uninstall
  . ./iam.sh        # AWS IAM security tasks
  . ./ec2_sec.sh    # AWS EC2 security tasks
  . ./ec2.sh        # AWS EC2 instance tasks
  . ./os_sec.sh     # OS hardening tasks
  . ./os_app.sh     # OS app tasks
  # . ./data.sh       # OS app tasks

  if [ "$aced_installed" != true ]; then
    # invoke install-related functions
    install          # ACED install
    iam              # AWS IAM tasks
    ec2_sec          # AWS EC2 security tasks
    ec2              # AWS EC2 instance tasks
    os_sec           # Ubuntu server hardening tasks
    os_app          # Ubuntu server app tasks
    # harden_accounts  # lock default EC2 account; require sudo pass $os_user

    # update config installed value
    aced_installed=true

    # invoke function to push updated value to ACED config
    aced_config_update aced_installed

    # sourced 2nd time to pickup new ACED alias
    . $HOME/.bash_profile

    echo -e "\n$blue \b*************************
     \b\b\b\b\b***  $aced_nm Installed!  ***
     \b\b\b\b\b*************************"

    echo -e "\n$yellow \bEnter $ $ec2_tag or $ $ec2_tag -h"

    # exit without error
    exit 0
  fi

  # strip off any prefixed hypen from passed argument
  option=${1/-/}

  # ACED parameter conditionals; bypass ACED task menu
  case $option in
    c|connect    ) ec2_connect        ;; # access instance via SSH
    eip          ) echo $ec2_ip       ;; # show public IP address
    lip          ) echo $localhost_ip ;; # show localhost public IP address
    on|start     ) ec2_state Stopped  ;; # start instance
    off|stop     ) ec2_state Running  ;; # stop instance
    r|reboot     ) ec2_reboot         ;; # reboot instance
    s|status     ) dashboard          ;; # show full AWS/EC2/ACED status
    u|uninstall  ) uninstall          ;; # remove ACED payload
    v|ver        ) version            ;; # show ACED version info
    \?|h|help    ) help               ;; # show ACED help
    *            ) task_menu          ;; # show ACED task menu: wildcard args
  esac
}

# invoke main ACED function; ingest any arguments as written
main "$@"
