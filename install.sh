#!/usr/bin/env bash

#################################################################
##  filename:   install.sh                                     ##
##  path:       ~/src/deploy/cloud/aws/                        ##
##  purpose:    create file structure & confirm prerequisites  ##
##  date:       03/16/2017                                     ##
##  repo:       https://github.com/DevOpsEtc/aced               ##
##  clone path: ~/aced/app/                                     ##
#################################################################

install() {
  clear
  version # invoke function to display ACED release info
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  ACED Install  XXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n$yellow"

  echo -e "\n$green \bCreating file structure..."
  mkdir -p $aced_root/{config/{aws/old,keys},data}

  # invoke function to check last command status code
  return_check

  if [ -d $aws_config ]; then
    echo -e "\n$green \bBacking up existing AWS config..."
    mv $aws_config $aced_aws/old/aws_"$(date +%m-%d-%Y_%H:%M:%S)"
    return_check
  fi

  if ! alias $ssh_alias > /dev/null; then
    echo -e "\n$green \bCreating permanent alias: $ec2_tag"
    echo "alias $ec2_tag='$aced_app/aced.sh'" >> $HOME/.bash_profile
    return_check
  fi
} # end function: install

uninstall() {
  echo -e "\n$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  ACED Uninstall  XXXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo $yellow; read -rp "Really uninstall ACED? [Y/N] " response

  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    echo -e "\n$green \bRemoving alias..."
    sed -i '' "/alias $ec2_tag=.*/d" ~/.bash_profile

    echo -e "\n$green \bRemoving ACED app directory..."
    rm -rf $aced_app

    echo $yellow; read -rp "Remove ACED config directory? [Y/N] " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$green \bRemoving ACED config directory..."
      rm -rf $aced_config
    fi

    echo $yellow; read -rp "Remove ACED data directory & repo? [Y/N] " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$green \bRemoving ACED data directory & repo..."
      rm -rf $aced_data
    fi

    echo -e "\n$green \bRemoving AWS configuration..."
    rm -rf ~/.aws

    echo -e "\n$green \bRemoving ssh connection alias..."
    sed -i '' "/## $ssh_alias ##/,/## $ssh_alias ##/d" ~/.ssh/config

    echo -e "\n$yellow \bACED was removed from localhost, but AWS IAM \
    \b\bgroup/user/access keys, EIP, EC2 instance, keypair, security \
    \b\bgroups/rules remain."

    version
    echo -e "\n$blue \bThanks for trying ACED!"
  fi
} # end function: uninstall
