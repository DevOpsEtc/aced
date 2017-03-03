#!/usr/bin/env bash

####################################################
##  filename:   ec2_sec.sh                        ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    security tasks pre-EC2 instance   ##
##  date:       03/01/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

# invoke all functions in this script
aed_ec2_sec() {
  echo done!
  # aed_ec2_sec_keypair
  # aed_ec2_sec_group
  # aed_ec2_sec_rules
}

aed_ec2_sec_keypair() {
  echo -e "$aed_wht
  \b\b######################################################
  \b\b##  Check Existing EC2 Key Pairs  ####################
  \b\b######################################################"

  # populate array with key-pair names
  aed_get_key_pair=($(aws ec2 describe-key-pairs \
    --query Groups[*].GroupName \
    --output text)
  )

  echo -e "\n$aed_grn \bChecking for existing EC2 key pair... $aed_rst"
  if [ $(aws ec2 describe-key-pairs | grep -q KeyName) ]; then
    echo -e "\n$aed_blu \bEC2 key pair found: \n $aed_rst"
    aws ec2 describe-key-pairs --output table

    # prompt to remove
    echo -e "$aed_ylw"
    read -rp "Delete key pair? [Y/N] " aed_opt

    # check for response
    if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$aed_grn \bDeleting key pair..."
      aws ec2 delete-key-pair --key-name \
        $(aws ec2 describe-key-pairs \
        --output text \
        --query 'KeyPairs[*].KeyName')
      echo -e "\n$aed_blu \bKey pair deleted!"
    else
      echo -e "\n$aed_ylw \bKey pair kept!"
    fi
  fi

  # check for key pair; do while not found
  while ! $(aws ec2 describe-key-pairs | grep -q KeyName); do
    echo -e "$aed_grn\n \bNo key pair found! Let's import one now. \n$aed_ylw"
    read -rp "Public key path set to: $aed_keys, Keep It? [Y/N] " aed_opt

    # check for response
    if [[ "$aed_opt" =~ ^([nN][oO]|[nN])+$ ]]; then
      # prompt for custom path
      echo -e "$aed_ylw"
      read -rp 'Enter custom public key path: ' aed_keys
    fi

    # prompt for filename
    echo -e "$aed_ylw"
    read -rp 'Enter public key filename, e.g. name_aws.pub: ' aed_key_name

    # check for public key at path; import if found, otherwise throw warning
    if [ -f $aed_keys/$aed_key_name ]; then
      # import key pair
      echo -e "\n$aed_grn \bImporting public key... \n$aed_rst"
      aws ec2 import-key-pair \
      --key-name $aed_key_name \
      --public-key-material file://$aed_keys/$aed_key_name
      echo -e "\n$aed_blu \bImport complete! \n$aed_rst"
    else
      echo -e "$aed_ylw\n \bPublic key: $aed_keys/$aed_key_name not found! "
    fi
  done
}

aed_ec2_sec_group() {
  ############################################################
  ####  check for existing EC2 security group  ###############
  ####  delete/create EC2 security group       ###############
  ############################################################

  # check for security-groups
  echo -e "$aed_grn \bChecking for existing EC2 security group... $aed_rst"
  if $(aws ec2 describe-security-groups | grep -q GroupName); then

    echo -e "\n$aed_blu \bEC2 security group found: \n $aed_rst"
    aws ec2 describe-security-groups --output table

    # prompt to remove
    echo -e "$aed_ylw"
    read -rp "Delete security group? [Y/N] " aed_opt

    # check for response
    if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$aed_grn \bDeleting security group..."
      aws ec2 delete-security-group --group-name \
        $(aws ec2 describe-security-groups \
          --query 'SecurityGroups[*].[GroupName]'
          --output text | grep -v "default")
      echo -e "\n$aed_blu \bSecurity group deleted!"
    fi
  fi

  # check for security group; do while not found
  while ! $(aws ec2 describe-security-groups | grep -q GroupName); do

    # prompt for security group name
    echo -e "$aed_ylw \n"
    read -rp 'Enter new security group name, e.g. blog-sg: ' aed_sec_group

    # prompt for security group description
    read -rp $'\nEnter security group description, e.g. Blog security group: ' \
      aed_sec_group_desc

    # create security group
    echo -e "\n$aed_grn \bAdding security group..."
    aws ec2 create-security-group \
      --group-name $aed_sec_group \
      --description "$aed_sec_group_desc"
  done
}

aed_ec2_sec_rules() {
  ############################################################
  ####  check for existing EC2 security group rules  #########
  ####  revoke/add EC2 security group rules          #########
  ############################################################

  # check for security group rules; do if found
  echo -e "\n$aed_grn \bChecking existing EC2 security group rules... $aed_rst"
  if $(aws ec2 describe-security-groups \
    --output text \
    --query 'SecurityGroups[*].{Name:GroupName}' \
    | grep -qv "default"); then

    echo -e "\n$aed_blu \bEC2 security group rule found: \n $aed_rst"
    aws ec2 describe-key-pairs --output table
  fi




  # add EC2 security group ingress rule
  aws ec2 authorize-security-group-ingress --group-name $aed_sec_group \
    --protocol tcp --port $aed_sec_rule_port --cidr $aed_ip_cidr



  # prompt for custom ssh access port
  read -rp $'\n\nEnter custom port for remote access, e.g. 1337: ' \
    aed_sec_rule_port

# separate function for -secRule
    # cidr vs. my IP
  # prompt for cidr format
  read -rp $'\n\nEnter ISP IP, e.g. 1337: ' aed_ip_cidr


  # create security group rules
  # add rule allowing inbound traffic on custom TCP port
  # public IP address in CIDR notation http://checkip.amazonaws.com
  # narrow to subnet
  # temp access via unknown ISP: add new rule @web console:
  # custom rule: tcp: port: : myIP
  $ aws ec2 authorize-security-group-ingress --group-name $aed_sec_group \
    --protocol tcp --port $aed_sec_rule_port --cidr $aed_ip_cidr
    # 50.170.168.0/24

  # view security group rules
  $ aws ec2 describe-security-groups --group-name $aed_sec_group

  # remove security group rule
  $ aws ec2 revoke-security-group-ingress \
    --group-name $aed_sec_group \
    --protocol tcp \
    --port $aed_sec_rule_port \
    --cidr $aed_ip_cidr
}
