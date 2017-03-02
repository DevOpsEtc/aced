#!/usr/bin/env bash

##############################################################
##  filename:     aed.sh													 	        ##
##  path:         ~/src/deploy/cloud/aws/						        ##
##  purpose:      run AED: Automated EC2 Deploy             ##
##  date:         03/01/2017											          ##
##  symlink:      $ ln -s ~/src/deploy/cloud/aws ~/aed/app  ##
##  repo:         https://github.com/DevOpsEtc/aed	        ##
##  clone path:   ~/aed/app/                                ##
##	source:		    $ . ~/aed/app/aed.sh                      ##
##	run:		      $ aed                                     ##
##  options:      -ip -on -off -reboot -rule -sec -status   ##
##  options:      -terminate -uninstall -ver                ##
##############################################################

aed_task_menu() {
  echo "AWS IAM/EC2 Tasks: launch|describe|terminate|start|stop|reboot|show IP"
}

aed_main() {
  ###############################################################
  ####  main AED function: install & run  #######################
  ###############################################################

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

  # check AED install status; invoke functions for install related tasks
  if [ "$aed_installed" != true ]; then
    aed_install    # invoke function for AED install
    aed_iam        # invoke function for AWS IAM tasks
    aed_ec2_sec    # invoke function for AWS EC2 security tasks
    # aed_os_sec     # invoke function for Ubuntu server hardening tasks
    # aed_os_app     # invoke function for Ubuntu server app tasks
  else
    aed_task_menu  # invoke IAM/EC2 task menu
  fi

  # store passed AED argument
  aed_option=$1

  # strip any included hypen
  aed_option=${aed_option/-/}

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
    *             ) aed_menu      ;; # IAM/EC2 task menu; unknown arguments
  esac
}

aed_main "$@"

# check installed status; source AED install scripts
# if [ "$aed_installed" != true ]; then
  # . $aed_app/install.sh   # AED install script
  # . $aed_app/iam.sh       # AWS IAM group/policy/user setup script

  # echo -e "$aed_grn
  # XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  # XXXXXXXX  AED Install:  XXXXXXXX
  # XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # bash $aed_app/os_sec.sh   # run server security hardening script
  # bash $aed_app/os_app.sh   # run app install/config script

  # update AED config value
  # sed -i '' 's/aed_installed=false/aed_installed=true/' $AED_ROOT/config.sh

  # source AED to pickup value change
  # . $aed_app/aed.sh
  # echo -e "\n$aed_blu \bAED Installed! \nEnter $ aed -h to see options $aed_rst"
# fi

# ingest any arguments
# "$@"
