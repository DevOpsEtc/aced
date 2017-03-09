#!/usr/bin/env bash

############################################################
##  filename:   aed.sh                                    ##
##  path:       ~/src/deploy/cloud/aws/                   ##
##  purpose:    run AED: Automated EC2 Deploy             ##
##  date:       03/08/2017                                ##
##  symlink:    $ ln -s ~/src/deploy/cloud/aws ~/aed/app  ##
##  repo:       https://github.com/DevOpsEtc/aed          ##
##  clone path: ~/aed/app/                                ##
##  execute:    $ ~/aed/app/aed.sh                        ##
##  run:        $ aed                                     ##
##  options:    -ip -on -off -reboot -rule -sec -status   ##
##  options:    -terminate -uninstall -ver                ##
############################################################

version() {
  ##########################################################
  ####  Display logo/version pre-rendered figlet  ##########
  ##########################################################

  echo -e "\n$blue
        _    _____ ____
       / \  | ____|  _ \\
      / _ \ |  _| | | | |
     / ___ \| |___| |_| |
    /_/   \_\_____|____/
    Automated EC2 Deploy

    Version:  $aed_ver
    Released: $aed_rel
    Author:   DevOpsEtc
  "
}

help() {
  ##########################################################
  ####  Display AED help & tips  ###########################
  ##########################################################

  echo -e "\n$yellow
    AED Commands: \n
    $ aed                    # AED: task menu
    $ aed -c or -connect     # EC2: remote access connect
    $ aed -ip                # EIP: rotate public IP
    $ aed -on or -start      # EC2: instance start
    $ aed -off or -stop      # EC2: instance stop
    $ aed -r or -rule        # EC2: remote access ingress rules
    $ aed -rb or -reboot     # EC2: instance reboot
    $ aed -s or -status      # EC2: instance status
    $ aed -sec or -security  # EC2: keys, group, & rule tasks
    $ aed -u or -uninstall   # AED: uninstall
    $ aed -v or -version     # AED: version information
    $ aed -? or -h or -help  # AED: help
  "
} # end function: help

ec2_dashboard() {
  # add call to spinner function
  # does instance exist
    # is it running
    # see logs: auth/ssh/web/etc
    # list processes
    # is website up
      # curl
  status_ec2() {
    :
  }
  status_server() {
    :
  }
  status_webserver() {
    :
  }
  status_www() {
    :
  }

} # end function: ec2_dashboard

tasks() {
  ##########################################################
  ####  Display AWS IAM & EC2 task menu  ###################
  ##########################################################
  clear
  ec2_dashboard   # invoke function to display server status
  COLUMNS=20          # force select menu to display vertically

  # populate array with menu options
  task_option=(
    "IAM: Rotate Access Keys"
    "EIP: Rotate IP Address"
    "EC2: Add Remote Access Rule"
    "EC2: See Instance Status"
    "EC2: Describe Instance"
    "EC2: Start Instance"
    "EC2: Stop Instance"
    "EC2: Reboot Instance"
    "EC2: Launch Instance"
    "EC2: Terminate Instance"
    "QUIT"
  ) # end function: tasks

  # loop menu until explicity quit
  while true; do
    echo -e "\n$green \bAED AWS Tasks: \n_________________________________\n"
    PS3=$'\nChoose task: '

    select t in "${task_option[@]}"; do
      case $t in
        "IAM: Rotate Access Keys")
          iam_user_keys
          break ;;
        "EIP: Rotate IP Address")
          break ;;
        "EC2: Rotate Key Pair")
          ec2_rotate_keys
          break ;;
        "EC2: Add Remote Access Rule")
          break ;;
        "EC2: See Instance Status")
          break ;;
        "EC2: Describe Instance")
          break ;;
        "EC2: Start Instance")
          break ;;
        "EC2: Stop Instance")
          break ;;
        "EC2: Reboot Instance")
          break ;;
        "EC2: Launch Instance")
          break ;;
        "EC2: Terminate Instance")
          break ;;
        "QUIT")
          return ;;
        *)
          echo -e "$yellow \nMust Enter Number: 1-${#task_option[@]} \
            $green\n"
          break ;;
      esac
    done # end select menu
  done # end of menu loop
} # end function: tasks

main() {
  ############################################################
  ####  Main AED function: install & run  ####################
  ############################################################

  # check if running script from mac; exit if not
  if [ "$(uname)" == "Darwin" ]; then
    # source scripts
    . ./config.sh     # AED config
    . ./install.sh    # AED install/uninstall
    . ./iam.sh        # AWS IAM security tasks
    . ./ec2_sec.sh    # AWS EC2 security tasks
    . ./ec2.sh        # AWS EC2 instance tasks
    # . ./os_sec.sh     # OS hardening tasks
    # . ./os_app.sh     # OS app tasks
    # . ./data.sh       # OS app tasks

    # invoke install functions if AED not installed
    if [ "$aed_install" == true ]; then
      install         # AED install
      iam             # AWS IAM tasks
      ec2_sec         # AWS EC2 security tasks
      ec2             # AWS EC2 instance tasks
      # os_sec          # Ubuntu server hardening tasks
      # os_app          # Ubuntu server app tasks
      sed -i '' '/installed=/ s/false/true /' $aed_app/config.sh
      echo -e "\n$blue \bAED Installed! \n\nEnter $ aed or $ aed -h"
    fi

    # strip off any prefixed hypen from passed argument
    option=${1/-/}

    # AED parameter conditionals
    case $option in
      c|connect     ) ssh aed    ;; # EC2 remote access connect
      ip            ) eip        ;; # EC2 rotate public IP
      on|start      ) ec2_start  ;; # EC2 instance start
      off|stop      ) ec2_stop   ;; # EC2 instance stop
      r|rule        ) ec2_rule   ;; # EC2 remote access ingress rules
      rb|reboot     ) ec2_reboot ;; # EC2 instance reboot
      s|status      ) ec2_status ;; # EC2 instance status
      sec|security  ) ec2_sec    ;; # EC2 keys, group, & rule tasks
      u|uninstall   ) uninstall  ;; # AED uninstall
      v|ver|version ) version    ;; # AED version information
      \?|h\help     ) help       ;; # AED help
      *             ) tasks      ;; # AED task menu; unknown arguments
    esac
  else
    echo -e "\n$red \bOops, You're Not Running MacOS! $reset"
    exit 0
  fi
} # end function: main

# invoke main AED function & ingest any arguments as written
main "$@"

exit 1
