#!/usr/bin/env bash

#############################################################
##  filename:   aced.sh                                    ##
##  path:       ~/src/deploy/cloud/aws/                    ##
##  purpose:    run ACED: Automated EC2 Deploy             ##
##  date:       04/03/2017                                 ##
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
    $ aced -u or -uninstall   # uninstall ACED
    $ aced -v or -version     # show ACED version information
    $ aced -? or -h or -help  # show ACED help
  "
}

dashboard() {
  ##########################################################
  ####  Display EC2 health status  #########################
  ##########################################################
  :
} # end function: dashboard

task_menu() {
  ##########################################################
  ####  Display AWS IAM & EC2 task menu  ###################
  ##########################################################

  clear
  dashboard     # invoke function to display EC2 status
  COLUMNS=20    # force select menu to display vertically

  # menu options array
  task_item=(
    "Start $aced_nm"
    "Stop $aced_nm"
    "Reboot $aced_nm"
    "List Group Rules"
    "Rotate Access Keys"
    "Rotate IP Address"
    "Rotate Key Pair"
    "Connect $aced_nm"
    "QUIT"
  )

  while true; do
    echo -e "$blue\n*** $aced_nm AWS Tasks ***\n"
    PS3=$'\nChoose task number: '
    select task in "${task_item[@]}"; do
      case $task in
        "Start $aced_nm"      ) ec2_state Stopped; break ;;
        "Stop $aced_nm"       ) ec2_state Running; break ;;
        "Reboot $aced_nm"     ) ec2_reboot;        break ;;
        "List Group Rules"    ) ec2_rule_list;     break ;;
        "Rotate Access Keys"  ) iam_keys_rotate;   break ;;
        "Rotate IP Address"   ) ec2_eip_rotate;    break ;;
        "Rotate Key Pair"     ) ec2_keypair;       break ;;
        "Connect $aced_nm"    ) ec2_connect;       break ;;
        "QUIT"                ) return                   ;;
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
    rb|reboot    ) ec2_reboot         ;; # reboot instance
    u|uninstall  ) uninstall          ;; # remove ACED payload
    v|ver        ) version            ;; # show ACED version info
    \?|h\help    ) help               ;; # show ACED help
    *            ) task_menu          ;; # show ACED task menu: wildcard args
  esac
}

main "$@" # invoke main ACED function; ingest any arguments as written
