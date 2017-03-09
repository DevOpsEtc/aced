#!/usr/bin/env bash

####################################################
##  filename:   config.sh                         ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    default AED settings              ##
##  date:       03/08/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

# Localhost File Paths
aed_root="$HOME/aed"                    # AED root
aed_app="$aed_root/app"                 # AED app path
aed_bin="$aed_root/bin"                 # AED bin path
aed_data="$aed_root/data"               # AED git repo
aed_config="$aed_root/config"           # AED config path
aed_keys="$aed_config/keys"             # AED key pair path
aed_aws="$aed_config/aws"               # AED AWS config path
aws_config="$HOME/.aws"                 # AWS default config path
ssh_config="$HOME/.ssh"                 # SSH config path
ssh_alias="aed"                         # AED SSH connection alias

# AWS Services
api_output=json                         # cli default output
api_region=us-west-1                    # cli default region
eip_address=000.000.000.000             # AWS EIP public IP address
iam_group=""                            # AWS IAM group name
iam_policy=""                           # AWS IAM policy name
iam_user=""                             # AWS IAM username
ec2_key=""                              # AWS EC2 public key name
ec2_group=""                            # AWS EC2 security group name
ec2_user=""                             # AWS EC2 OS username
ec2_id=""                               # AWS EC2 instance ID
ec2_tag=""                              # AWS EC2 instance tag

# Misc
aed_ver="1.0.0"                         # AED version number
aed_rel="03/01/2017"                    # AED release date
aed_install=true                        # AED install status
icon_pass="✔"                          # checkmark symbol
icon_fail="✘"                           # X symbol
# icon_pass="\xE2\x9C\x94"                # checkmark symbol (UTF-8 hex)
# icon_fail="\xE2\x9C\x98"                # X symbol
blue=$(tput bold && tput setaf 33)      # bold blue text
yellow=$(tput bold && tput setaf 136)   # bold yellow text
green=$(tput bold && tput setaf 64)     # bold green text
red=$(tput bold && tput setaf 160)      # bold red text
white=$(tput bold && tput setaf 255)    # bold white text
reset=$(tput sgr0)                      # reset text attributes
