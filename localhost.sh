#!/usr/bin/env bash

#################################################################
##  filename:   localhost.sh                                     ##
##  path:       ~/src/deploy/cloud/aws/                        ##
##  purpose:    create file structure & confirm prerequisites  ##
##  date:       04/03/2017                                     ##
##  repo:       https://github.com/DevOpsEtc/aced              ##
##  clone path: ~/aced/app/                                    ##
#################################################################

install() {
  clear
  version # invoke function to display ACED release info
  sleep 2
  echo -e "$white
  \b\b#########################################
  \b\b########  ACED Install  #################
  \b\b#########################################"

  echo -e "\n$green \bCreating file structure..."
  mkdir -p $aced_root/{config/{backups/{aws,ssh},keys},data}

  # invoke function to check last command status code
  exit_code_check

  if [ -d $aws_config ]; then
    echo -e "\n$green \bBacking up existing AWS config... \n$blue"
    mv $aws_config $aced_backups/aws/aws_"$(date +%m-%d-%Y_%H-%M)"
    exit_code_check
  fi

  if [ -d $ssh_config ]; then
    echo -e "\n$green \bBacking up existing SSH config... \n$blue"
    cp -R $ssh_config $aced_backups/ssh/ssh_"$(date +%m-%d-%Y_%H-%M)"
    exit_code_check
  fi

  if ! alias $ssh_alias > /dev/null; then
    echo -e "\n$green \bCreating permanent alias: $ec2_tag"
    echo "alias $ec2_tag='$aced_app/aced.sh'" >> $HOME/.bash_profile
    exit_code_check
  fi
}

ec2_warn_multiple() {
  echo -e "\n$red \b*** Running multiple EC2 instances will exceed free-tier \
  \b\blimit: 750 hours/month ***"
}

decision_response() {
  ###################################################
  ####  Display decision/prompt for response     ####
  ####  e.g: $ decision_response Are you tired?  ####
  ###################################################
  argument_check

  # concatenate parameter
  decision=$*

  while true; do
    read -n 1 -p $'\n'"$yellow""$decision (Y/N) $reset" response
    case $response in
      y|Y ) echo; break ;;
      n|N ) echo; break ;;
      *   ) echo; echo -e "\n$red \bInvalid Input! $reset" ;;
    esac
  done
}

ec2_lip_fetch() {
  echo -e "\n$green \bChecking localhost public IP address..."
  ip_raw=$(curl -s http://checkip.amazonaws.com)
  exit_code_check

  # strip any leading zeros from IP octets; prevent AWS malformed error
  localhost_ip=$(echo $localhost_ip \
    | awk -F'[.]' '{a=$1+0; b=$2+0; c=$3+0; d=$4+0; print a"."b"."c"."d"/32"}')
}

ssh_alias_create() {
  if [ "$1" == "update" ]; then
    echo -e "\n$green \bUpdating SSH connection alias: $ssh_alias..."
    # escape all dots in IP
    ip_escaped=$(echo $ec2_ip | sed -e 's/\./\\./g')
    # match pattern; do substitutes on N lines below match
    sed -i '' \
      -e "/Host $ssh_alias/ { N; s/HostName .*/HostName $ip_escaped/; }" \
      -e "/HostName $ip_escaped/ { N; s/User .*/User $os_user/; }" \
      -e "/User $os_user/ { N; s/Port .*/Port $ec2_ssh_port/; }" \
      ~/.ssh/config
    exit_code_check
    return
  fi

  echo -e "\n$green \bChecking for existing $aced_nm SSH connection alias..."
  if grep -qw "Host $ssh_alias" ~/.ssh/config; then
    # delete line prior to match via hold space
    sed -i '' -n "/## $ssh_alias ##/{x;d;};1h;1!{x;p;};\${x;p;}" ~/.ssh/config
    # delete lines between matching patterns
    sed -i '' "/## $ssh_alias ##/,/## \/$ssh_alias ##/d" ~/.ssh/config
    exit_code_check

    if [ "$1" == "remove" ]; then
      return
    fi
  else
    echo -e "\n$blue \bNo ACED SSH connection alias found!"
  fi

  echo -e "\n$green \bCreating SSH connection alias: $ssh_alias..."
  echo -e " \
    \n## $ssh_alias ############################ \
    \nHost $ssh_alias \
    \n  HostName $ec2_ip \
    \n  User $os_user_def \
    \n  Port 22 \
    \n  IdentityFile $aced_keys/$ssh_key_private \
    \n## /$ssh_alias ###########################" \
    >> ~/.ssh/config
  exit_code_check

  echo -e "\n$green \bSetting file permissions on ~/.ssh/config to 600..."
  chmod u=rw,go-rwx ~/.ssh/config
  exit_code_check
}

uninstall() {
  echo -e "\n$white
  \b\b#########################################
  \b\b########  ACED Uninstall  ###############
  \b\b#########################################"

  # invoke function to display decision/capture response
  decision_response Really uninstall $aced_nm?

  # bail from uninstall if responds with "n" or "N"
  [[ "$response" =~ [nN] ]] && { echo -e "$red\n\nUninstall Stopped!"; exit; }

  echo -e "\n$green \bRemoving alias..."
  sed -i '' "/alias $ec2_tag=.*/d" ~/.bash_profile
  exit_code_check

  echo -e "\n$green \bRemoving AWS configuration..."
  rm -rf $aws_config &>/dev/null
  exit_code_check

  ssh_alias_create remove # invoke function to remove ssh connection alias

  if ssh-add -L | grep -q "$aced_keys/$ssh_key_private"; then
    echo -e "\n$green \bRemoving $aced_nm private key from localhost SSH \
    \b\bagent... \n"
    ssh-add -d $aced_keys/$ssh_key_private &>/dev/null
    exit_code_check
  fi

  # remove localhost keypair

  decision_response Remove $aced_nm config directory?
  if [[ "$response" =~ [yY] ]]; then
    echo -e "\n$green \bRemoving $aced_nm config directory..."
    rm -rf $aced_config &>/dev/null
    exit_code_check
  else
    aced_root_rm=false
  fi

  decision_response Remove $aced_nm data directory & repo?
  if [[ "$response" =~ [yY] ]]; then
    echo -e "\n$green \bRemoving $aced_nm data directory & repo..."
    rm -rf $aced_data &>/dev/null
    exit_code_check
  else
    aced_root_rm=false
  fi

  if [ $aced_root_rm != false ]; then
    rm -rf $aced_root &>/dev/null
    exit_code_check
  else
    echo -e "\n$green \bRemoving $aced_nm app directory..."
    rm -rf $aced_app &>/dev/null
    exit_code_check

    echo -e "\n$yellow \bHere are the files you chose to keep: \n"
    find ~/aced/* -type f -maxdepth 4
  fi

  echo -e "\n$yellow \b$aced_nm uninstall complete! \
  \n\nReview AWS web console to manage your remaining IAM & EC2 resources"

  version
  echo -e "\n$blue \bThanks for trying $aced_nm!"
} # end function: uninstall
