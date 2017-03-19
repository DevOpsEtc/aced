#!/usr/bin/env bash

#####################################################
##  filename:   config.sh                          ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    default ACED settings              ##
##  date:       03/17/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

# Localhost File Paths
aced_root="$HOME/aced"                  # ACED root
aced_app="$aced_root/app"               # ACED app path
aced_data="$aced_root/data"             # ACED git repo
aced_config="$aced_root/config"         # ACED config path
aced_keys="$aced_config/keys"           # ACED key pair path
aced_aws="$aced_config/aws"             # ACED AWS config path
aws_config="$HOME/.aws"                 # AWS default config path

# Locahlhost
ssh_key_private="aced_key"              # PKI private key
ssh_key_public="aced_key.pub"           # PKI pubic key (imported to AWS)
ssh_alias="aced"                        # ACED SSH connection alias
public_ip="000.000.000.000"             # localhost public IP & 32-bit netmask

# AWS Resources
ec2_vpc_id="vpc-example!"               # AWS virtual private cloud ID
aws_output="json"                       # aws-cli default command output
aws_region="us-west-1"                  # aws-cli default region
aws_type="t2.micro"                     # aws-cli default EC2 instance type
ec2_ip="000.000.000.000"                # EIP public IP address
iam_group="Aced_Admins"                 # IAM user group name
iam_group_desc="ACED Administrators"    # IAM user group description
iam_policy_iam="Aced_Policy_IAM"        # IAM policy: IAM permissions
iam_policy_ec2="Aced_Policy_EC2"        # IAM policy: EC2 permissions
iam_user="Aced_User"                    # IAM username
iam_key_id="THISJUSTAPLACEHOLDER"       # IAM access key ID for $iam_user
ec2_ami_owner="099720109477"            # AMI owner: Canonical (Ubuntu)
ec2_ami_name="xenial"                   # AMI owner: Ubuntu server code name
ec2_ami_ver="16.04"                     # AMI owner: current Ubuntu LTS
ec2_group="Aced_Sec_Group"              # EC2 security group name
ec2_group_id="sg-example!"              # EC2 security group ID
ec2_group_desc="ACED Security Group"    # EC2 security group description
ec2_user="ace"                          # EC2 OS username
ec2_user_def="ubuntu"                   # EC2 OS default user baked into AMI
ec2_temp_pass="top_secret"              # EC2 OS temporary password for ec2_user
ec2_id="i-ThisIsOnlyExample"            # EC2 instance ID
ec2_tag="aced"                          # EC2 instance tag

# Misc
aced_title="ACED"                       # ACED version number
aced_ver="1.0.0"                        # ACED version number
aced_rel="03-09-2017"                   # ACED release date
aced_installed=false                    # ACED install status
icon_pass="✔"                          # command return status: 0
icon_fail="✘"                           # command return status: 1
blue=$(tput bold && tput setaf 33)      # bold blue text
yellow=$(tput bold && tput setaf 136)   # bold yellow text
green=$(tput bold && tput setaf 64)     # bold green text
red=$(tput bold && tput setaf 160)      # bold red text
white=$(tput bold && tput setaf 255)    # bold white text
gray=$(tput setaf 8)                    # bold white text
reset=$(tput sgr0)                      # reset text attributes

# AWS URLs
aws_con=http://$aws_region.console.aws.amazon.com/ec2/v2/home?region=$aws_region
cli_aws=http://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html
