#!/usr/bin/env bash

###########################################################
##  filename:   aced.sh                                  ##
##  path:       ~/src/deploy/cloud/aws/                  ##
##  purpose:    run ACED: Automated EC2 Deploy           ##
##  date:       03/17/2017                               ##
##  symlink:    $ ln -s ~/src/deploy/cloud/aws ~/aced    ##
##  repo:       https://github.com/DevOpsEtc/aced        ##
##  clone path: ~/aced/app/                              ##
##  execute:    $ ~/aced/app/aced.sh                     ##
##  run:        $ aced                                   ##
##  options:    -ip -on -off -reboot -rule -status  ##
##  options:    -terminate -uninstall -ver               ##
###########################################################

version() {
  ##########################################################
  ####  Display logo/version pre-rendered figlet  ##########
  ##########################################################

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
  ##########################################################
  ####  Display ACED help & tips  ###########################
  ##########################################################

  echo -e "\n$yellow
    ACED Commands: \n
    $ aced                    # show ACED task menu
    $ aced -c or -connect     # access ACED instance via SSH
    $ aced -ip                # show ACED public IP address
    $ aced -on or -start      # start ACED instance
    $ aced -off or -stop      # stop ACED instance
    $ aced -rb or -reboot     # reboot ACED instance
    $ aced -s or -status      # show ACED instance status
    $ aced -u or -uninstall   # uninstall ACED
    $ aced -v or -version     # show ACED version information
    $ aced -? or -h or -help  # show ACED help
  "
} # end function: help

ec2_dashboard() {
  ##########################################################
  ####  Display EC2 health status  #########################
  ##########################################################
  :
} # end function: ec2_dashboard

aced_tasks() {
  ##########################################################
  ####  Display AWS IAM & EC2 task menu  ###################
  ##########################################################

  clear
  ec2_dashboard   # invoke function to display EC2 status
  COLUMNS=20      # force select menu to display vertically

  # populate array with menu options
  task_option=(
    "Start EC2 Instance"
    "Stop EC2 Instance"
    "Reboot EC2 Instance"
    "List EC2 Group Rules"
    "Rotate IAM Access Keys"
    "Rotate EC2 IP Address"
    "Rotate EC2 Key Pair"
    "Connect EC2 Instance"
    "QUIT"
  )

  while true; do
    echo -e "\n$green \bACED AWS Tasks:
    \n_________________________________\n"
    PS3=$'\nChoose task: '

    select t in "${task_option[@]}"; do
      case $t in
        "Start EC2 Instance")
          ec2_start
          break ;;
        "Stop EC2 Instance")
          ec2_stop
          break ;;
        "Reboot EC2 Instance")
          ec2_reboot
          break ;;
        "List EC2 Group Rules")
          ec2_sec_rule_list
          break ;;
        "Rotate IAM Access Keys")
          iam_keys_rotate
          break ;;
        "Rotate EC2 IP Address")
          ec2_eip_rotate
          break ;;
        "Rotate EC2 Key Pair")
          ec2_sec_keypair
          break ;;
        "Connect EC2 Instance")
          ec2_connect
          break ;;
        "QUIT")
          return ;;
        *)
          echo -e "$yellow \nMust Enter Number: 1-${#task_option[@]} $green\n"
          break ;;
      esac # conditionals end
    done # menu end
  done # menu loop end
} # function end: aced_tasks

return_check() {
  ##########################################################
  ####  Check status code of last command  #################
  ##########################################################

  if [ $? -eq 0 ]; then
    echo -e "\n$blue $icon_pass Success!"
  else
    echo -e "\n$red $icon_fail Failure!"
    exit 1 # exit installer with error
  fi
}

update_config() {
  ##########################################################
  ####  Push updated value to ACED config  ##################
  ##########################################################

  if [ "$#" -gt 0 ]; then
    for i in "$@"; do
      echo -e "\n$green \bPushing value: $i = ${!i} to $aced_title config..."

      if [ ! $i == "aced_installed" ]; then
        # find line pattern; substitute characters inside quotes with arg value
        sed -i '' "/$i/ s/\".*\"/\"${!i}\"/" $aced_app/config.sh
      else
        sed -i '' '/aced_installed/ s/false/true /' $aced_app/config.sh
      fi
      return_check
    done
  else
    echo -e "\n$red \bNo arguments supplied! $reset"
    return
  fi
}

show_active() {
  #########################################################
  ##  Display visual cue for longer running processes    ##
  ##  Note: process must be in parent shell; no child    ##
  ##  e.g. $ sleep 10 & show_active                      ##
  ##  Note: & command sends prior command to background  ##
  #########################################################
  pid=$!            # fetch last process ID
  frames='◓◑◒◐'  # animation frames
  i=0               # frame cycle count
  tput civis        # hide cursor; unhide: tput cnorm
  printf "\n"
  while kill -0 $pid &>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\b${green}${frames:$i:1}"
    sleep .1
  done
  printf "\n"
  tput cnorm
}

main() {
  ###############################################################
  ####  Main ACED function: install and/or display task menu  ####
  ###############################################################

  # bail if not run from MacOS or if aws-cli not found
  [[ $(uname) == "Darwin" ]] || { echo -e "\nACED needs MacOS!"; exit 1; }
  type -p aws >/dev/null || { echo -e "\nACED needs aws-cli!"; exit 1; }

  # set shell option enabling alias expansion for alias test; source aliases
  shopt -s expand_aliases && . ~/.bash_profile

  # set path of ACED scripts
  cd "$(dirname $0)" || exit 1

  # source scripts
  . ./config.sh     # ACED config
  . ./install.sh    # ACED install/uninstall
  . ./iam.sh        # AWS IAM security tasks
  . ./ec2_sec.sh    # AWS EC2 security tasks
  . ./ec2.sh        # AWS EC2 instance tasks
  # . ./os_sec.sh     # OS hardening tasks
  # . ./os_app.sh     # OS app tasks
  # . ./data.sh       # OS app tasks

  if [ "$aced_installed" != true ]; then
    # invoke functions for ACED installation
    install         # ACED install
    iam             # AWS IAM tasks
    ec2_sec         # AWS EC2 security tasks
    # ec2             # AWS EC2 instance tasks
    # os_sec          # Ubuntu server hardening tasks
    # os_app          # Ubuntu server app tasks

    # update installed config value
    aced_installed=true

    # invoke function to push updated value to ACED config
    update_config aced_installed

    # sourced 2nd time to pickup new ACED alias
    . $HOME/.bash_profile

    echo -e "\n$yellow \bACED Installed! \n\nEnter $ aced or $ aced -h"

    # exit without error
    exit 0
  fi

  # strip off any prefixed hypen from passed argument
  option=${1/-/}

  # ACED parameter conditionals; bypass ACED task menu
  case $option in
    c|connect    ) ec2_connect   ;; # access instance via SSH
    ip           ) echo $ec2_ip  ;; # show public IP address
    on|start     ) ec2_start     ;; # start instance
    off|stop     ) ec2_stop      ;; # stop instance
    rb|reboot    ) ec2_reboot    ;; # reboot instance
    s|status     ) ec2_status    ;; # show instance status
    u|uninstall  ) uninstall     ;; # remove ACED payload
    v|ver        ) version       ;; # show ACED version info
    \?|h\help    ) help          ;; # show ACED help
    *            ) aced_tasks    ;; # show ACED task menu: wildcard arguments
  esac
}

main "$@" # invoke main ACED function; ingest any arguments as written
