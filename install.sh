#!/usr/bin/env bash

#################################################################
##  filename:   install.sh                                     ##
##  path:       ~/src/deploy/cloud/aws/                        ##
##  purpose:    create file structure & confirm prerequisites  ##
##  date:       03/10/2017                                     ##
##  repo:       https://github.com/DevOpsEtc/aed               ##
##  clone path: ~/aed/app/                                     ##
#################################################################

install() {
  clear
  version # invoke function: AED release info
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  AED Install  XXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n$yellow"

  read -rp "Do you have a free account at AWS yet? [Y/N] " response

  if [[ "$response" =~ ^([nN][oO]|[nN])+$ ]]; then
    echo -e "\n$green \bOpening AWS website to free tier page... \n$yellow"
    open https://aws.amazon.com/free/
    read -p "Create account, then press enter key to continue"
  fi

  echo -e "\n$green \bLooking for the aws-cli app..."
  # check for aws-cli app; eat stout; notify if not found
  if ! type aws &>/dev/null; then
    echo -e "\n$yellow \baws-cli app not found! $yellow"
    open http://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html
    read -p "Install aws-cli, then press enter key to continue"
  else
    echo -e "\n$blue $icon_pass $yellow"
  fi

  # create file structure & list results
  echo -e "\n$green \bCreating file structure..."
  mkdir -p $aed_root/{config/{aws/old,keys},data}

  # invoke function to check status code of last command
  return_check

  # list new directories
  echo -e "$blue"; find $aed_root -type d -maxdepth 2

  if ! alias aed > /dev/null; then
    echo -e "\n$green \bCreating permanent alias: $ssh_alias"
    echo "alias aed='\$HOME/aed/app/aed.sh'" >> $HOME/.bash_profile
    return_check
  fi
}

update_config() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  Update AED Config  XXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  # check for any arguments
  if [ "$#" -gt 0 ]; then
    # loop through arguments
    for i in "$@"; do
      echo -e "\n$green \bUpdating $i: value: ${!i}..."
      sed -i '' "s/$i=.*/$i=\"${!i}\"/" $aed_app/config.sh
      return_check
    done
    echo $reset
  else
    echo -e "\n$red \bNo arguments supplied! $reset"
    return
  fi
}

uninstall() {
  echo -e "\n$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  AED Uninstall  XXXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo $yellow; read -rp "Really uninstall AED? [Y/N] " response

  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    # echo -e "\n$green \bRemoving AED shell functions..."
    # rmFun=$(declare -F | awk '/\ / {print $3}')
    # unset -f $rmFun
    #
    # echo -e "\n$green \bRemoving AED shell variables..."
    # rmVar=$(set | awk '/^/ {sub(/=.*/,""); print}')
    # unset $rmVar rmVar

    # echo -e "\n$green \bRemoving alias..."
    # unalias aed

    # echo -e "\n$green \bRemoving AED app directory..."
    # rm -rf $aed_app


    # To Do: sed kill alias in bash_profile

    echo $yellow; read -rp "Remove AED bin directory? [Y/N] " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$green \bRemoving AED bin directory..."
      rm -rf $aed_bin
    fi

    echo $yellow; read -rp "Remove AED config directory? [Y/N] " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$green \bRemoving AED config directory..."
      rm -rf $aed_config
    fi

    echo $yellow; read -rp "Remove AED data directory & repo? [Y/N] " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$green \bRemoving AED data directory..."
      rm -rf $aed_data
    fi

    echo -e "\n$green \bRemoving symlinks to AWS configuration..."
    rm -rf ~/.aws

    echo -e "\n$green \bRemoving ssh connection alias..."
    sed -i '' "/^Host $ssh_alias$/{N;N;N;N;N;d;}" $ssh_config/config

    echo -e "\n$yellow \bAED was removed from localhost, but AWS IAM \
    \b\bgroup/user/access keys, EIP, EC2 instance, keypair, security \
    \b\bgroups/rules remain."

    # invoke function to display logo & version
    version
    echo -e "\n$blue \bThanks for trying AED!"
  fi
} # end function: uninstall
