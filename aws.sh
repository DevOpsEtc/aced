#!/usr/bin/env bash

#####################################################
##  filename:   aws.sh                             ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    AWS related functions              ##
##  date:       05/01/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

aws_waiter() {
  ###########################################################
  ##  Kludge to avoid intermittent AWS credentials errors  ##
  ##  e.g. InvalidClientTokenId & AuthFailure              ##
  ##  Tests last command's exist code for failure & loop   ##
  ###########################################################

  while true; do
    if [ $1 == "IAM" ]; then
      aws iam get-user &>/dev/null
      [[ $? -eq 0 ]] && break
    elif [ $1 == "EC2" ]; then
      aws ec2 describe-instances &>/dev/null
      [[ $? -eq 0 ]] && break
    elif [ $1 == "SSH" ]; then
      if [ $# -eq 1 ]; then
        nc -z $ec2_ip $port &>/dev/null
        [[ $? -eq 0 ]] && break
      elif [ $2 == "silent" ]; then
        nc -z $ec2_ip_last $os_ssh_port &>/dev/null
        [[ $? -eq 0 ]] && break
      fi
    elif [ $1 == "HTTPS" ]; then
      ssh $ssh_alias "systemctl status nginx | grep 'running' -q"
      [[ $? -eq 0 ]] && break
    fi
    sleep 2
  done
  if [ $1 != HTTPS ]; then
    echo -e "\n\n$blue$icon_pass $1 Ready"'!'" $reset"
  fi
}

aws_cli_config() {
  echo -e "\n$white \b****  AWS: CLI Configure  ****"

  argument_check

  if [ "$1" == "root" ]; then
    if [ -d $aws_config ]; then
      echo -e "\n$green \bBacking up AWS config to: \
        \n\n$blue \b$aced_backups/aws/aws_"$(date +%m-%d-%Y_%H-%M)"... "
      rsync -a --exclude='.*' /$aws_config/ \
        /$aced_backups/aws/aws_"$(date +%m-%d-%Y_%H-%M)"
      cmd_check
      rm -rf $aws_config &>/dev/null
    fi

    access_keys=$2
  else
    rm -rf $aws_config &>/dev/null
    access_keys=$1
  fi

  # extracts individual keys
  echo -e "\n$green \bExtracting Access Key ID..."
  iam_key_id=$(awk '/AWSAccessKeyId/ {gsub(/AWSAccessKeyId=/, ""); print $1}' \
    $access_keys)
  cmd_check

  echo -e "\n$green \bExtracting Secret Access Key..."
  iam_key_secret=$(awk '/AWSSecretKey/ {gsub(/AWSSecretKey=/, ""); print $1}' \
    $access_keys)
  cmd_check

  # removes any trailing non-printable character (seen intermittently)
  iam_key_id=${iam_key_id%$'\r'}
  iam_key_secret=${iam_key_secret%$'\r'}

  echo -e "\n$green \bAWS Configure: pushing extracted credentials..."
  aws configure set aws_access_key_id "$iam_key_id" \
    && aws configure set aws_secret_access_key "$iam_key_secret"
  cmd_check

  echo -e "\n$green \bDeleting temporary credentials file... \n$blue"
  rm -f $access_keys
  cmd_check

  if [[ $access_keys =~ [rootkey] ]]; then
    echo -e "\n$green \bAWS Configure: pushing config..."
    aws configure set default.region "$aws_region" \
    && aws configure set default.output "$aws_output" \
    && aws configure set default.metadata_service_num_attempts "$aws_retry" \
    && aws configure set default.metadata_service_timeout "$aws_timeout"
    cmd_check
  fi

  echo -e "\n$green \bWaiting on AWS to accept IAM commands... "
  aws_waiter IAM &
  activity_show
} # end func: aws_cli_config
