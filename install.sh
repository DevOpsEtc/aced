#!/usr/bin/env bash

############################################################################
##  filename:     install.sh												                      ##
##  path:         ~/src/deploy/cloud/aws/						                      ##
##  purpose:      check prerequisites, create file structure, set config  ##
##  date:         02/26/2017												                      ##
##  repo:         https://github.com/DevOpsEtc/aed	                      ##
##  clone path:   ~/aed/app/                                              ##
############################################################################

aed_install() {
  clear
  # invoke function to display logo & version number
  aed_version
  echo -e "\n$green
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  AED Install:  XXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # spin function check; source parent script; eat stdout & stderr
  if ! type -t spin &>/dev/null; then
    # script check; grab if not found
    if [ ! -f $AED_BIN/spinner.sh ]; then
      cd $AED_BIN && \
      echo
      echo -e "$yellow \bcurl command here; update after pushing new repo"
      # curl -sO https://raw.githubusercontent.com/DevOpsEtc/bin/master/spinner.sh
    fi
    # . $AED_BIN/spinner.sh # source script
    echo -e "\n$yellow \bsource spinner.sh, update this after pushing new repo"
  fi

  # create file structure & list results
  echo -e "\n$green \bCreating file structure..."
  mkdir -p ~/aed/{bin,config,repo}
  echo -e "\n$blue \bCreated: "; find ~/aed -type d -maxdepth 1

  # audit prerequisites
  echo -e "\n$green \bBefore continuing, there are some prerequisites... $yellow\n"

  # prompt for aws account prerequisite
  read -r -p "Are you signed up for a free acount at AWS yet? [Y/N] " response

  # check for response
  if [[ "$response" =~ ^([nN][oO]|[nN])+$ ]]; then
    echo -e "\n$green \bOpening AWS website to free tier page... \n$yellow"
    # open aws free tier info page using default browser
    open https://aws.amazon.com/free/

    # prompt to continue
    read -p "Create a free AWS account, then press enter key to continue"
  fi

  echo -e "\n$green \bLooking for the aws-cli app..."
  # check for aws-cli app; eat stout; notify if not found
  if ! type aws &>/dev/null; then
    echo -e "\n$yellow \bThe aws-cli app was not found! $yellow"
    open http://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html

    # prompt to continue
    read -p "Install aws-cli, then press enter key to continue"
  else
    echo -e "\n$blue \bThe aws-cli app was found! $green"
  fi

  # prompt for key pair prerequisite
  read -r -p $'\n'"Do you have a public-key encryption key pair? [Y/N] " response

  # check for response
  if [[ "$response" =~ ^([nN][oO]|[nN])+$ ]]; then
    # script check; grab if not found
    if [ ! -f $AED_BIN/key_pair.sh ]; then
      cd $AED_BIN && \
      curl -sO https://raw.githubusercontent.com/DevOpsEtc/bin/master/key_pair.sh
    fi
    echo -e "\n$green \bGenerate public-key encryption key pair..."
    # execute key pair script
    bash $AED_BIN/key_pair.sh
  fi

  echo -e "\n$yellow \bLooks like you have all the prerequisites!"
}

aed_uninstall() {
  echo -e "\n$green
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXX  AED Uninstall:  XXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # prompt to remove
  echo -e "$yellow" && read -r -p "Really uninstall AED? [Y/N] " response

  # check for response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then

    # array of items to prompt for deletion
    rmDir=(bin config repo)

    echo -e "\n$green \bRemoving AED shell functions..."
    rmFunc=$(declare -F | grep aed | awk '{print $3}')
    unset -f $rmFunc

    echo -e "\n$green \bRemoving AED variables..."
    unset


    echo -e "\n$green \bRemoving AED directories and file..."
    rm -rf $AED_ROOT # remove AED files
    rm -rf ~/.aws   # remove symlinks to AWS config

    # call function to display logo & version
    aed_version
    echo -e "\n$blue \bThanks for trying AED!"

    # kill this too? or prompt for decision
    echo -e "\n$yellow \bAED was removed from localhost, but the ssh \
    connection alias remains for your convenience at ~/.ssh/config. \
    \n\nYour IAM group/user/access keys, EIP, EC2 instance, keypair, \
    security groups/rules and ssh connection alias were untouched."
  fi
}
