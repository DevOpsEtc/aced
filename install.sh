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
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  AED Install Tasks  XXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n$aed_ylw"

  read -rp "Do you have a free acount at AWS yet? [Y/N] " aed_opt

  if [[ "$aed_opt" =~ ^([nN][oO]|[nN])+$ ]]; then
    echo -e "\n$aed_grn \bOpening AWS website to free tier page... \n$aed_ylw"
    open https://aws.amazon.com/free/
    read -p "Create account, then press enter key to continue"
  fi

  echo -e "\n$aed_grn \bLooking for the aws-cli app..."
  # check for aws-cli app; eat stout; notify if not found
  if ! type aws &>/dev/null; then
    echo -e "\n$aed_ylw \baws-cli app not found! $aed_ylw"
    open http://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html
    read -p "Install aws-cli, then press enter key to continue"
  else
    echo -e "\n$aed_blu $aed_ok_icon $aed_ylw"
  fi

  # create file structure & list results
  echo -e "\n$aed_grn \bCreating file structure..."
  mkdir -p $aed_root/{config/{aws,keys},data} \
    && echo -e "\n$aed_blu $aed_ok_icon" || return
  echo -e "$aed_blu"; find $aed_root -type d -maxdepth 2






  # check for/create alias that sources AED
  if alias | grep -qw 'aed='; then
    unalias aed
    echo -e "\n$aed_grn \bCreating alias..."
    alias aed='. ~/aed/app/aed.sh' \
      && echo -e "\n$aed_blu $aed_ok_icon" || return
  fi




}

aed_update_config() {
  echo -e "$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  Update AED Config  XXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  # check for any arguments
  if [ "$#" -gt 0 ]; then
    # loop through arguments
    for i in "$@"; do
      echo -e "\n$aed_grn \bUpdating $i: value: ${!i}..."
      sed -i '' "s/$i=.*/$i=\"${!i}\"/" $aed_app/config.sh \
        && echo -e "\n$aed_blu $aed_ok_icon $aed_grn" || return
    done
    echo $aed_rst
  else
    echo -e "\n$aed_red \bNo arguments supplied! $aed_rst"
    return
  fi
}

aed_uninstall() {
  echo -e "\n$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  AED Uninstall  XXXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

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
