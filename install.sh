#!/usr/bin/env bash

#################################################################
##  filename:   install.sh                                     ##
##  path:       ~/src/deploy/cloud/aws/                        ##
##  purpose:    create file structure & confirm prerequisites  ##
##  date:       03/03/2017                                     ##
##  repo:       https://github.com/DevOpsEtc/aed               ##
##  clone path: ~/aed/app/                                     ##
#################################################################

aed_install() {
  clear
  aed_version # invoke function: AED release info
  echo -e "$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  AED Install:  XXXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # create file structure & list results
  echo -e "\n$aed_grn \bCreating file structure..."
  mkdir -p $aed_root/{bin,config/aws,data,keys}
  echo -e "$aed_blu"; find $aed_root -type d -maxdepth 2

  # check for/create alias that sources AED
  echo -e "\n$aed_grn \bCreating alias..."
  if ! alias | grep -qw 'aed='; then
    alias aed='. ~/aed/app/aed.sh'
  fi

  echo -e "$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  Confirm Prerequisites:  XXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n $aed_ylw"

  # prompt for aws account prerequisite
  read -rp "Are you signed up for a free acount at AWS yet? [Y/N] " aed_opt

  if [[ "$aed_opt" =~ ^([nN][oO]|[nN])+$ ]]; then
    echo -e "\n$aed_grn \bOpening AWS website to free tier page... \n$aed_ylw"
    # open aws free tier info page using default browser
    open https://aws.amazon.com/free/

    read -p "Create a free AWS account, then press enter key to continue"
  fi

  echo -e "\n$aed_grn \bLooking for the aws-cli app..."
  # check for aws-cli app; eat stout; notify if not found
  if ! type aws &>/dev/null; then
    echo -e "\n$aed_ylw \bThe aws-cli app was not found! $aed_ylw"
    open http://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html

    # prompt to continue
    read -p "Install aws-cli, then press enter key to continue"
  else
    echo -e "\n$aed_blu \bThe aws-cli app was found! $aed_ylw"
  fi

  # prompt for key pair prerequisite
  read -rp $'\n'"Do you have a public-key encryption keypair? [Y/N] " aed_opt

  if [[ "$aed_opt" =~ ^([nN][oO]|[nN])+$ ]]; then
    # script check; grab if not found
    if [ ! -f $aed_bin/key_pair.sh ]; then
      cd $aed_bin || exit
      curl -sO \
      https://raw.githubusercontent.com/DevOpsEtc/bin/master/key_pair.sh
    fi
    echo -e "\n$aed_grn \bGenerate public-key encryption key pair..."
    # execute key pair script
    bash $aed_bin/key_pair.sh
  fi

  echo -e "\n$aed_ylw \bPrerequisites confirmed!"
} # end function: aed_install

aed_uninstall() {
  echo -e "\n$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  AED Uninstall:  XXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo $aed_ylw; read -rp "Really uninstall AED? [Y/N] " aed_opt

  if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    echo -e "\n$aed_grn \bRemoving AED shell functions..."
    aed_rmFun=$(declare -F | awk '/\ aed_/ {print $3}')
    unset -f $aed_rmFun

    echo -e "\n$aed_grn \bRemoving AED shell variables..."
    aed_rmVar=$(set | awk '/^aed_/ {sub(/=.*/,""); print}')
    unset $aed_rmVar aed_rmVar

    echo -e "\n$aed_grn \bRemoving alias..."
    unalias aed

    echo -e "\n$aed_grn \bRemoving AED app directory..."
    rm -rf $aed_app

    echo $aed_ylw; read -rp "Remove AED bin directory? [Y/N] " aed_opt

    if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$aed_grn \bRemoving AED bin directory..."
      rm -rf $aed_bin
    fi

    echo $aed_ylw; read -rp "Remove AED config directory? [Y/N] " aed_opt

    if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$aed_grn \bRemoving AED config directory..."
      rm -rf $aed_config
    fi

    echo $aed_ylw; read -rp "Remove AED data directory & repo? [Y/N] " aed_opt

    if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$aed_grn \bRemoving AED data directory..."
      rm -rf $aed_data
    fi

    echo -e "\n$aed_grn \bRemoving symlinks to AWS configuration..."
    rm -rf $aed_aws_dotfile

    echo -e "\n$aed_grn \bRemoving ssh connection alias..."
    sed -i '' "/^Host $aed_ssh_alias$/{N;N;N;N;N;d;}" $aed_ssh_cfg

    echo -e "\n$aed_ylw \bAED was removed from localhost, but AWS IAM \
    \b\bgroup/user/access keys, EIP, EC2 instance, keypair, security \
    \b\bgroups/rules remain."

    # invoke function to display logo & version
    aed_version
    echo -e "\n$aed_blu \bThanks for trying AED!"
  fi
} # end function: aed_uninstall
