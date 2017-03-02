#!/usr/bin/env bash

##############################################################
##  filename:     aed.sh                                    ##
##  path:         ~/src/deploy/cloud/aws/                   ##
##  purpose:      run AED: Automated EC2 Deploy             ##
##  date:         03/02/2017                                ##
##  symlink:      $ ln -s ~/src/deploy/cloud/aws ~/aed/app  ##
##  repo:         https://github.com/DevOpsEtc/aed          ##
##  clone path:   ~/aed/app/                                ##
##  source:       $ . ~/aed/app/aed.sh                      ##
##  run:          $ aed                                     ##
##  options:      -ip -on -off -reboot -rule -sec -status   ##
##  options:      -terminate -uninstall -ver                ##
##############################################################

aed_version() {
  ############################################################
  ####  Display logo/version info in pre-rendered figlet  ####
  ############################################################

  echo -e "\n$aed_blu
        _    _____ ____
       / \  | ____|  _ \\
      / _ \ |  _| | | | |
     / ___ \| |___| |_| |
    /_/   \_\_____|____/
    Automated EC2 Deploy

    Version:  1.0.0
    Released: 03/01/2017
    Author:   DevOpsEtc
  "
}

aed_help() {
  ############################################################
  ####  Display AED help & tips  #############################
  ############################################################

  echo -e "\n$aed_ylw
    AED Commands: \n
    $ aed                    # IAM/EC2 task menu
    $ aed -c or -connect     # EC2 remote access connect
    $ aed -ip                # EC2 rotate public IP
    $ aed -on or -start      # EC2 instance start
    $ aed -off or -stop      # EC2 instance stop
    $ aed -r or -rule        # EC2 remote access ingress rules
    $ aed -rb or -reboot     # EC2 instance reboot
    $ aed -s or -status      # EC2 instance status
    $ aed -sec or -security  # EC2 keys, group, & rule tasks
    $ aed -t or -terminate   # EC2 instance deletion
    $ aed -u or -uninstall   # AED uninstall
    $ aed -v or -version     # AED version information
    $ aed -? or -h or -help  # AED help
  "
}

aed_tasks() {
  ############################################################
  ####  Display AWS IAM & EC2 task menu  #####################
  ############################################################

  echo "AWS IAM/EC2 Tasks: launch|describe|terminate|start|stop|reboot|show IP"
}

aed_main() {
  ############################################################
  ####  Main AED function: install & run  ####################
  ############################################################

  # AED sourced scripts array
  aed_scripts=(
    config.sh      # AED config
    install.sh     # AED install/uninstall
    iam.sh         # AWS IAM security tasks
    ec2_sec.sh     # AWS EC2 security tasks
    # ec2.sh         # AWS EC2 instance tasks
    # os_sec.sh      # OS hardening tasks
    # os_app.sh      # OS app tasks
    # data.sh        # OS app tasks
  )

  # loop through script list; source each script
  for i in "${aed_scripts[@]}"; do
    . ~/aed/app/$i
  done

  # check AED install status; invoke AED install related functions
  if [ "$aed_installed" == false ]; then
    aed_install    # invoke function for AED install
    aed_iam        # invoke function for AWS IAM tasks
    aed_ec2_sec    # invoke function for AWS EC2 security tasks
    # aed_os_sec     # invoke function for Ubuntu server hardening tasks
    # aed_os_app     # invoke function for Ubuntu server app tasks
    sed -i '' '/aed_installed=/ s/false/true /' $aed_app/config.sh
    echo -e "\n$aed_blu \bAED Installed! \nEnter $ aed or $ aed -h"
  fi

  # strip off any prefixed hypen from passed argument
  aed_option=${1/-/}

  # AED parameter conditionals
  case $aed_option in
    c|connect     ) ssh aws       ;; # EC2 remote access connect
    ip            ) aed_eip       ;; # EC2 rotate public IP
    on|start      ) aed_start     ;; # EC2 instance start
    off|stop      ) aed_stop      ;; # EC2 instance stop
    r|rule        ) aed_ec2_rule  ;; # EC2 remote access ingress rules
    rb|reboot     ) aed_reboot    ;; # EC2 instance reboot
    s|status      ) aed_status    ;; # EC2 instance status
    sec|security  ) aed_ec2_sec   ;; # EC2 keys, group, & rule tasks
    t|terminate   ) aed_terminate ;; # EC2 instance deletion
    u|uninstall   ) aed_uninstall ;; # AED uninstall
    v|ver|version ) aed_version   ;; # AED version information
    \?|h\help     ) aed_help      ;; # AED help
    *             ) aed_tasks     ;; # IAM/EC2 task menu; unknown arguments
  esac
}

# invoke main AED function & ingest any arguments as written
aed_main "$@"
