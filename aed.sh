#!/usr/bin/env bash

#################################################################
##  filename:     aed.sh													 	           ##
##  path:         ~/src/deploy/cloud/aws/						           ##
##  purpose:      run AED: Automated EC2 Deploy                ##
##  date:         02/26/2017											             ##
##  symlink:      $ ln -s ~/src/deploy/cloud/aws ~/aed/app     ##
##  repo:         https://github.com/DevOpsEtc/aed	           ##
##  clone path:   ~/aed/app/                                   ##
##	source:		    $ . ~/aed/app/aed.sh                         ##
##	run:		      $ aed                                        ##
##  options:      -help -ip -on -off -reboot -reset -rule      ##
##  options:      -sec -status -terminate -uninstall -version  ##
#################################################################

aed() {
  ###############################################################
  ####  main AED function: install & run  #######################
  ###############################################################

  # assign AED path
  AED_APP=~/aed/app

  # AED sourced scripts array
  scriptList=(
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
  for i in "${scriptList[@]}"; do
    . $AED_APP/$i
  done

  # check AED install status; invoke functions for install related tasks
  if [ "$AED_INSTALLED" != true ]; then
    aed_install
    aed_iamAll
    aed_ec2SecAll
    # aed_ec2All
    # aed_osSecAll
    # aed_osAppAll
  fi

  # store passed AED argument
  option=$1

  # strip any included hypen
  option=${option/-/}

  # AED parameter conditionals
  case $option in
    ip|eip      ) aed_eip       ;; # Elastic IP task
    on|start    ) aed_start     ;; # start EC2 instance
    off|stop    ) aed_stop      ;; # stop EC2 instance
    r|rule      ) aed_secRule   ;; # add|remove temporary remote access rule
    rb|reboot   ) aed_reboot    ;; # reboot EC2 instance
    sg|sec      ) aed_secAll    ;; # import|add|delete EC2 keys/groups/rules
    ssh|connect ) ssh aws       ;; # connnect to remote EC2 server cli via alias
    st|status   ) aed_status    ;; # list EC2 instance status
    t|terminate ) aed_terminate ;; # delete EC2 instance
    u|uninstall ) aed_uninstall ;; # AED uninstall
    v|version   ) aed_version   ;; # AED version number & date
    *           ) aed_help      ;; # AED help; unknown or no argument wildcard;
  esac
}

# check installed status; source AED install scripts
# if [ "$AED_INSTALLED" != true ]; then
  # . $AED_APP/install.sh   # AED install script
  # . $AED_APP/iam.sh       # AWS IAM group/policy/user setup script

  # echo -e "$green
  # XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  # XXXXXXXX  AED Install:  XXXXXXXX
  # XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # bash $AED_APP/os_sec.sh   # run server security hardening script
  # bash $AED_APP/os_app.sh   # run app install/config script

  # update AED config value
  # sed -i '' 's/AED_INSTALLED=false/AED_INSTALLED=true/' $AED_ROOT/config.sh

  # source AED to pickup value change
  # . $AED_APP/aed.sh
  # echo -e "\n$blue \bAED Installed! \nEnter $ aed -h to see options $rs"
# fi

# ingest any arguments
# "$@"
