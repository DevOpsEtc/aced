#!/usr/bin/env bash

####################################################
##  filename:   config.sh                         ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    default AED settings              ##
##  date:       03/10/2017                        ##
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
ssh_key_private="aed_key"               # PKI private key
ssh_key_public="aed_key.pub"            # PKI pubic ke7 (imported to AWS)

# AWS Resources
aws_output="json"                       # cli default output
aws_region="us-west-1"                  # cli default region
eip_address="000.000.000.000"           # EIP public IP address
iam_group="AED_Admins"                  # IAM user group name
iam_group_desc="AED Administrators"     # IAM user group name
iam_pol_iam="AED_Policy_IAM"            # IAM policy: IAM permissions
iam_pol_ec2="AED_Policy_EC2"            # IAM policy: EC2 permissions
iam_user="AED_User"                     # IAM username
iam_key=""                              # IAM access key ID for $iam_user
ec2_group="AED_Sec_Group"               # EC2 security group name
ec2_group_desc="AED_Sec_Group"          # EC2 security group name
ec2_ami="ami-16efb076"                  # EC2 AMI ID
ec2_user="ace"                          # EC2 OS username
ec2_default_user="ubuntu"               # EC2 OS default username
ec2_id=""                               # EC2 instance ID
ec2_tag="aed-01"                        # EC2 instance tag
ec2_ssh_port=1337                       # EC2 SSH port; reduces log clutter
ec2_access_ip_hm="000.000.000.000/24"   # EC2 ingress IP: home netmask 24
ec2_access_ip_wk="000.000.000.000/24"   # EC2 ingress IP: work netmask 24
ec2_access_ip_pub="000.000.000.000/32"  # EC2 ingress IP: public netmask 32
ec2_access_ip_nutz="0.0.0.0/0"          # EC2 ingress IP: anywhere

# Misc
aed_ver="1.0.0"                         # AED version number
aed_rel="03/09/2017"                    # AED release date
aed_installed=false                     # AED install status
icon_pass="✔"                          # command return status: 0
icon_fail="✘"                           # command return status: 1
blue=$(tput bold && tput setaf 33)      # bold blue text
yellow=$(tput bold && tput setaf 136)   # bold yellow text
green=$(tput bold && tput setaf 64)     # bold green text
red=$(tput bold && tput setaf 160)      # bold red text
white=$(tput bold && tput setaf 255)    # bold white text
gray=$(tput setaf 8)                    # bold white text
reset=$(tput sgr0)                      # reset text attributes
