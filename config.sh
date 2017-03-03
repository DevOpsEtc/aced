#!/usr/bin/env bash

####################################################
##  filename:   config.sh                         ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    default AED settings              ##
##  date:       03/03/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

# assign default AED values
aed_ver="1.0.0"                        # AED release version
aed_installed=false                    # AED installed status
aed_ip=000.000.000.000                 # AWS EC2 public IP address
aed_root=~/aed                         # AED root
aed_app=$aed_root/app                  # AED app path
aed_bin=$aed_root/bin                  # AED bin path
aed_data=$aed_root/data                # AED git repo
aed_config=$aed_root/config            # AED config path
aed_keys=$aed_config/keys              # AED key pair path
aed_aws=$aed_config/aws                # AWS config path
aed_aws_cfg=$aed_aws/config            # AWS config file
aed_aws_crd=$aed_aws/credentials       # AWS credentials file
aed_aws_crd_tmp=$aed_aws/creds_tmp     # AWS temp credentials file
aed_aws_dotfile=~/.aws                 # AWS dotfile path
aed_aws_dotfile_bk=$aed_aws/aws_bk     # AWS dotfile backup
aed_ssh_dotfile=~/.ssh                 # SSH dotfile path
aed_ssh_cfg=$aed_ssh_dotfile/config    # SSH config file
aed_ssh_alias=aed                      # SSH connection alias

# placeholders for AED values; populated post-install
aed_eip_address=000.000.000.000
aed_iam_group_name=
aed_iam_policy_name=
aed_iam_user_name=
aed_ec2_instance_id=
aed_ec2_user_name=

# assign pretty text attributes
aed_blu=$(tput bold && tput setaf 33)  # bold blue
aed_ylw=$(tput bold && tput setaf 136) # bold yellow
aed_grn=$(tput bold && tput setaf 64)  # bold green
aed_red=$(tput bold && tput setaf 160) # bold red
aed_wht=$(tput bold && tput setaf 255) # bold white
aed_rst=$(tput sgr0)                   # reset attributes
