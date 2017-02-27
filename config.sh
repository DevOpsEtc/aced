#!/usr/bin/env bash

############################################################
##  filename:     config  												        ##
##  path:         ~/src/deploy/cloud/aws/						      ##
##  purpose:      file paths, preference values & config  ##
##  date:         02/26/2017												      ##
##  repo:         https://github.com/DevOpsEtc/aed	      ##
##  clone path:   ~/aed/app/                              ##
############################################################

# variables
export AED_ROOT=~/aed                     # AED root
export AED_APP=$AED_ROOT/app
export AED_BIN=$AED_ROOT/bin              # AED bin path
export AED_CONFIG=$AED_ROOT/config        # AED config file
export AWS_CONFIG=$AED_CONFIG/aws         # AWS dotfile path
export AWS_CFG=$AWS_CONFIG/config         # AWS dotfile path
export AWS_CRD=$AWS_CONFIG/creds          # AWS dotfile path
export AWS_CRD_TMP=$AWS_CONFIG/creds_tmp  # AWS dotfile path
export AWS_DOTFILE=~/.aws                 # AWS dotfile path
export AWS_DOTFILE_BK=$AWS_CONFIG/aws_bk  # AWS dotfile path
export AED_REPO=$AED_ROOT/repo            # git repo
export AED_VER="1.0.0"                    # release version
export AED_INSTALLED=false                # installed status

# pretty text attributes (color & weight)
export blue=$(tput bold)$(tput setaf 33)
export yellow=$(tput bold)$(tput setaf 136)
export green=$(tput bold)$(tput setaf 64)
export red=$(tput bold)$(tput setaf 160)
export rs=$(tput sgr0)

aed_version(){
  ##############################################################
  ####  display logo & version number; pre-rendered figlet  ####
  ##############################################################

  echo -e "\n$blue
        _    _____ ____
       / \  | ____|  _ \\
      / _ \ |  _| | | | |
     / ___ \| |___| |_| |
    /_/   \_\_____|____/
    Automated EC2 Deploy

    Version:  1.0.0
    Released: 02/26/2017
    Author:   DevOpsEtc"
}

aed_help() {
  ##############################################################
  ####  display AED help & tips  ###############################
  ##############################################################

  echo -e "\n$yellow
    AED Command Options: \n
    $ aed -ip or -eip         # allocate|associate|release Elastic IP
    $ aed -on or -start       # start EC2 instance
    $ aed -off or -stop       # stop EC2 instance
    $ aed -r or -rule         # add|remove temporary remote access rule
    $ aed -rb or -reboot      # reboot EC2 instance
    $ aed -rs or -reset       # delete AED env vars; invoke install
    $ aed -sg or -sec         # import|add|delete EC2 keys/groups/rules
    $ aed -ssh or -connect    # connect to remote EC2 server cli
    $ aed -st or -status      # list EC2 instance status
    $ aed -t or -terminate    # delete EC2 instance
    $ aed -u or -uninstall    # AED uninstall
    $ aed -v or -version      # AED release version information
    $ aed -? or -h or -help   # AED command options listing"
}
