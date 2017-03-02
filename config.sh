#!/usr/bin/env bash

############################################################
##  filename:     config  												        ##
##  path:         ~/src/deploy/cloud/aws/						      ##
##  purpose:      file paths, preference values & config  ##
##  date:         03/01/2017												      ##
##  repo:         https://github.com/DevOpsEtc/aed	      ##
##  clone path:   ~/aed/app/                              ##
############################################################

# assign default values
aed_ver="1.0.0"                        # AED release version
aed_installed=false                    # AED installed status
aed_ip=000.000.000.000                 # AWS EC2 public IP address
aed_root=~/aed                         # AED root
aed_app=$aed_root/app                  # AED app path
aed_aws=$aed_config/aws                # AWS config path
aed_bin=$aed_root/bin                  # AED bin path
aed_data=$aed_root/data                # AED git repo
aed_config=$aed_root/config            # AED config path
aed_keys=$aed_config/keys              # AED key pair path
aed_aws_cfg=$aed_aws/config            # AWS config file
aed_aws_crd=$aed_aws/creds             # AWS credentials file
aed_aws_crd_tmp=$aed_aws/creds_tmp     # AWS temp credentials file
aed_aws_dotfile=~/.aws                 # AWS dotfile path
aed_aws_dotfile_bk=$aed_aws/aws_bk     # AWS dotfile backup
aed_ssh_dotfile=~/.ssh                 # SSH dotfile path
aed_ssh_cfg=$aed_ssh_dotfile/config    # SSH config file
aed_ssh_alias=aed                      # SSH connection alias

# assign pretty text attributes
aed_blu=$(tput bold && tput setaf 33)  # bold blue
aed_ylw=$(tput bold && tput setaf 136) # bold yellow
aed_grn=$(tput bold && tput setaf 64)  # bold green
aed_red=$(tput bold && tput setaf 160) # bold red
aed_rst=$(tput sgr0)                   # reset attributes

aed_version(){
  ##############################################################
  ####  display logo & version number; pre-rendered figlet  ####
  ##############################################################

  echo -e "\n$aed_blu
        _    _____ ____
       / \  | ____|  _ \\
      / _ \ |  _| | | | |
     / ___ \| |___| |_| |
    /_/   \_\_____|____/
    Automated EC2 Deploy

    Version:  1.0.0
    Released: 03/01/2017
    Author:   DevOpsEtc"
}

aed_help() {
  ##############################################################
  ####  display AED help & tips  ###############################
  ##############################################################

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
