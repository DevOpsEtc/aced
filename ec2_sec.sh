#!/usr/bin/env bash

######################################################
##  filename:   ec2_sec.sh												  ##
##  path:       ~/src/deploy/cloud/aws/						  ##
##  purpose:    security tasks pre-EC2 instance     ##
##  date:       02/27/2017												  ##
##  repo:       https://github.com/DevOpsEtc/aed		##
##  clone path:   ~/aed/app/                        ##
######################################################

# invoke all functions in this script
aed_ec2SecAll() {
  aed_ec2SecKeypair
  aed_ec2SecGroup
  aed_ec2SecRules
}

aed_ec2SecKeypair() {
  echo -e "$green
  \b\b##############################################
  \b\b##  EC2 Key Pairs  ###########################
  \b\b##############################################"

  echo -e "\n$green \bChecking for existing EC2 key pair... $rs"
  if $(aws ec2 describe-key-pairs | grep -q KeyName); then

    echo -e "\n$blue \bEC2 key pair found: \n $rs"
    aws ec2 describe-key-pairs --output table

    # prompt to remove
    echo -e "$yellow"
    read -r -p "Delete key pair? [Y/N] " response

    # check for response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$green \bDeleting key pair..."
      aws ec2 delete-key-pair --key-name \
        $(aws ec2 describe-key-pairs \
        --output text \
        --query 'KeyPairs[*].KeyName')
      echo -e "\n$blue \bKey pair deleted!"
    else
      echo
    fi
  fi

  # check for key pair; do while not found
  while ! $(aws ec2 describe-key-pairs | grep -q KeyName); do

    # public key path
    deployKeyPath=~/src/config/keys

    echo -e "$green\n \bNo key pair found! Let's import one now. \n$yellow"
    read -r -p "Public key path set to: $deployKeyPath, Keep It? [Y/N] " response

    # check for response
    if [[ "$response" =~ ^([nN][oO]|[nN])+$ ]]; then
      # prompt for custom path
      echo -e "$yellow"
      read -p 'Enter custom public key path: ' deployKeyPath
    fi

    # prompt for filename
    echo -e "$yellow"
    read -p 'Enter public key filename, e.g. name_aws.pub: ' deployKey

    # check for public key at path; import if found, otherwise throw warning
    if [ -f $deployKeyPath/$deployKey ]; then
      # import key pair
      echo -e "\n$green \bImporting public key... \n$rs"
      aws ec2 import-key-pair --key-name $deployKey --public-key-material \
      file://$deployKeyPath/$deployKey
      echo -e "\n$blue \bImport complete! \n$rs"
    else
      echo -e "$yellow\n \bPublic key: $deployKeyPath/$deployKey not found! "
    fi
  done
}

aed_ec2SecGroup() {
  ############################################################
  ####  check for existing EC2 security group  ###############
  ####  delete/create EC2 security group       ###############
  ############################################################

  # check for security-groups
  echo -e "$green \bChecking for existing EC2 security group... $rs"
  if $(aws ec2 describe-security-groups | grep -q GroupName); then

    echo -e "\n$blue \bEC2 security group found: \n $rs"
    aws ec2 describe-security-groups --output table

    # prompt to remove
    echo -e "$yellow"
    read -r -p "Delete security group? [Y/N] " response

    # check for response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$green \bDeleting security group..."
      aws ec2 delete-security-group --group-name \
        $(aws ec2 describe-security-groups \
          --query 'SecurityGroups[*].[GroupName]'
          --output text | grep -v "default")
      echo -e "\n$blue \bSecurity group deleted!"
    fi
  fi

  # check for security group; do while not found
  while ! $(aws ec2 describe-security-groups | grep -q GroupName); do

    # prompt for security group name
    echo -e "$yellow \n"
    read -p 'Enter new security group name, e.g. blog-sg: ' \
      deploySecGroup

    # prompt for security group description
    read -p $'\nEnter security group description, e.g. Blog security group: ' \
      deploySecGroupDes

    # create security group
    echo -e "\n$green \bAdding security group..."
    aws ec2 create-security-group --group-name $deploySecGroup \
      --description "$deploySecGroupDes"
  done
}

aed_ec2SecRules() {
  ############################################################
  ####  check for existing EC2 security group rules  #########
  ####  revoke/add EC2 security group rules          #########
  ############################################################

  # check for security group rules; do if found
  echo -e "\n$green \bChecking for existing EC2 security group rules... $rs"
  if $(aws ec2 describe-security-groups \
    --output text \
    --query 'SecurityGroups[*].{Name:GroupName}' | \
    grep -qv "default"); then

    echo -e "\n$blue \bEC2 security group rule found: \n $rs"
    aws ec2 describe-key-pairs --output table
  fi
  # list
  # revoke
  # add

  # menu: add temp: flag via var

  # temp ingress rule for remote access to EC2 instance

  # get public IP; add CIDR notation
  AWS_SOURCE_IP_TEMP=$(curl http://checkip.amazonaws.com)/32

  # permanently store value for new shells
  echo "export AWS_SOURCE_IP=$(curl http://checkip.amazonaws.com)/32 >> \
    $configPath/$config"



  # add EC2 security group ingress rule
  aws ec2 authorize-security-group-ingress --group-name $deploySecGroup \
    --protocol tcp --port $deploySecRulePort --cidr $deploySecRuleIp



  # prompt for custom ssh access port
  read -p $'\n\nEnter custom port for remote access, \
    e.g. 1337: ' deploySecRulePort

# separate function for -secRule
    # cidr vs. my IP
  # prompt for cidr format
  read -p $'\n\nEnter ISP IP, \
    e.g. 1337: ' deploySecRuleIp


  # create security group rules
  # add rule allowing inbound traffic on custom TCP port
  # public IP address in CIDR notation http://checkip.amazonaws.com
  # narrow to subnet
  # temp access via unknown ISP: add new rule @web console:
  # custom rule: tcp: port: : myIP
  $ aws ec2 authorize-security-group-ingress --group-name $deploySecGroup \
    --protocol tcp --port $deploySecRulePort --cidr $deploySecRuleIp
    # 50.170.168.0/24

  # view security group rules
  $ aws ec2 describe-security-groups --group-name blog-sg

  # remove security group rule
  $ aws ec2 revoke-security-group-ingress --group-name blog-sg --protocol tcp --port 222 --cidr 50.170.168.0/24
}
