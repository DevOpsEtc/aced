#!/usr/bin/env bash

#####################################################
##  filename:   ec2.sh                             ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    launch instance & initial config   ##
##  date:       04/03/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

ec2() {
  echo -e "$white
  \b\b#########################################
  \b\b###  EC2: Launch/EIP/SSH Alias/User  ####
  \b\b#########################################"
  ec2_launch        # check existing; grab AMI; launch new instance
  ec2_eip_create    # check existing; allocate new; associate with EC2
  ssh_alias_create  # check existing; create/update connection alias
}

ec2_eip_rotate() {
  ec2_eip_create rotate    # remove ACED EIP; allocate & associate new ACED EIP
  ssh_alias_create update  # update ssh connection alias with new IP
}

ec2_state() {
  echo -e "\n$green \bChecking $aced_nm's current state..."
  state=$(aws ec2 describe-instances \
    --instance-ids $ec2_id \
    --query Reservations[].Instances[].State.Name \
    --output text)
  exit_code_check

  # title-case string
  state=$(echo $state | awk '{$1=toupper(substr($1,0,1))substr($1,2)}1')

  if [ "$1" != "ssh" ]; then
    # bail if current state already matches desired state
    [[ "$1" == "$state" ]] || { echo -e "$yellow\nOops, Already $state!"; \
      return; }
  fi

  if [ "$1" = "Stopped" ]; then
    echo -e "\n$green \bStarting $aced_nm... \n$blue"
    aws ec2 start-instances --instance-ids $ec2_id

    aws ec2 wait instance-running --instance-ids "$ec2_id" &
    activity_show
    exit_code_check

    ec2_eip_create  # invoke function to allocate & associate EIP
    ssh_alias_create update
  elif [ "$1" = "Running" ]; then
    decision_response Stop $aced_nm?
    if [[ "$response" =~ [yY] ]]; then
      ec2_eip_remove  # invoke function to disassociate & release EIP

      echo -e "$green\nStopping $aced_nm... \n$blue"
      aws ec2 stop-instances --instance-ids $ec2_id

      aws ec2 wait instance-stopped --instance-ids "$ec2_id" &
      activity_show
      exit_code_check
    fi
  fi
}

ec2_reboot() {
  ec2_state_check Running
  echo -e "$white\n**** Stopping & Starting $aced_nm ****"
  ec2_state Running
  ec2_state Stopped
}

ec2_connect() {
  ec2_state ssh # invoke function to check current state of $aced_nm

  if [ "$state" != "Running" ]; then
    echo -e "\n$red \bCan't connect to $aced_nm, because it's NOT running!"
    return
  fi

  ec2_lip_fetch

  if [ $ip_raw/32 != "$localhost_ip" ]; then
    echo -e "\n$yellow \bLocalhost IP has changed!"
    ec2_rule_ingress_add lip_update # add ingress rule for new IP; revoke old
    localhost_ip=$ip_raw
    aced_config_update localhost_ip
  fi

  echo -e "\n$yellow \bConnecting to EC2 instance: $ec2_tag \n$reset"
  ssh $ssh_alias  # ssh connection to EC2 instance
}

ec2_terminate() {
  argument_check
  ec2_eip_remove $1 # invoke function to check existing/remove EIP; pass $ec2_id

  echo -e "\n$green \bTerminating Instance ID: $1... \n$blue"
  aws ec2 terminate-instances --instance-ids "$1"

  aws ec2 wait instance-terminated --instance-ids "$1" &
  activity_show
  exit_code_check
}

ec2_launch() {
  echo -e "\n$white \b****  EC2: Instance Launch  ****"

  echo -e "\n$green \bChecking for existing EC2 instances..."
  ec2_instances=($(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values= \
    pending,running,shutting-down,stopping,stopped" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text)
  )
  exit_code_check

  if [ ${#ec2_instances[@]} -gt 0 ]; then
    for i in "${ec2_instances[@]}"; do
      echo -e "\n$blue \bEC2 instance found: $i"

      echo -e "\n$green \bChecking for tag name: $ec2_tag"
      ec2_instance_tag=$(aws ec2 describe-instances \
        --instance-ids "$i" \
        --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' \
        --output text)
      exit_code_check

      if [ "$ec2_instance_tag" == "$ec2_tag" ]; then
        echo -e "\n$blue \bEC2 instance with tag: $ec2_tag found!"
        ec2_terminate "$i" # invoke function to terminate; pass instance-id
      else
        echo -e "\n$blue \bNo matching tag found!"

        ec2_warn_multiple

        decision_response Terminate instance: $i?
        [[ "$response" =~ [yY] ]] && ec2_terminate "$i"
      fi
    done
  else
    echo -e "\n$blue \bNo EC2 instances found!"
  fi

  echo -e "\n$green \bFetching latest AMI ID for Ubuntu Server 16.04 LTS..."
  ami_id=$(aws ec2 describe-images \
    --region $aws_region \
    --owners $ec2_ami_owner \
    --filters \
      Name=virtualization-type,Values=hvm \
      Name=root-device-type,Values=ebs \
      Name=architecture,Values=x86_64 \
      Name=name,Values=*hvm-ssd/ubuntu-$ec2_ami_name-$ec2_ami_ver* \
    --query 'sort_by(Images, &Name)[-1].ImageId' \
    --output text)
  exit_code_check
  echo -e "\n$blue \bLatest AMI ID: $ami_id"

  echo -e "\n$green \bFetching AMI's name..."
  ami_name=$(aws ec2 describe-images --image-ids $ami_id \
    --query "Images[*].Name" \
    --output text)
  exit_code_check
  echo -e "\n$blue \bAMI's name: $ami_name"

  echo -e "\n$green \bLaunching EC2 Instance Id: $ami_id..."
  ec2_id=$(aws ec2 run-instances \
    --image-id $ami_id \
    --count 1 \
    --instance-type t2.micro \
    --key-name $ssh_key_public \
    --security-groups $ec2_group \
    --block-device-mappings "[{ \
      \"DeviceName\":\"/dev/sda1\",\"Ebs\":{ \
      \"VolumeSize\":30, \
      \"DeleteOnTermination\":true}}]" \
    --query 'Instances[*].InstanceId' \
    --output text)
  exit_code_check

  echo -e "\n$green \bWaiting for EC2 Instance to start..."
  aws ec2 wait instance-running --instance-ids "$ec2_id" &
  activity_show

  aced_config_update ec2_id

  echo -e "\n$green \bAdding name tag: $ec2_tag to $ec2_id..."
  aws ec2 create-tags \
    --resources "$ec2_id" \
    --tags Key=Name,Value="$ec2_tag"
  exit_code_check

  echo -e "\n$yellow \bReview EC2 instances in AWS web console:"
  echo -e "\n$yellow \b$aws_con#Instances"
}

ec2_eip_remove() {
  echo -e "\n$green \bChecking for existing EIPs..."
  eip_ids=($(aws ec2 describe-addresses \
    --query Addresses[*].AllocationId \
    --output text)
  )
  exit_code_check

  if [ ${#eip_ids[@]} -gt 0 ]; then
    for e in "${eip_ids[@]}"; do
      echo -e "\n$blue \bFound EIP, allocation ID: $e"
      echo -e "\n$green \bChecking for EC2 instance association..."
      eip_instance_id=$(aws ec2 describe-addresses \
        --allocation-ids $e \
        --query Addresses[*].InstanceId \
        --output text)
      exit_code_check

      if [ -n "$eip_instance_id" ]; then
        echo -e "\n$blue \bAssociated with instance ID: $eip_instance_id"
        echo -e "\n$green \bFetching EC2 association ID..."
        eip_assoc_id=$(aws ec2 describe-addresses \
        --allocation-ids $e \
        --query Addresses[*].AssociationId \
        --output text)
        exit_code_check
        echo -e "\n$blue \bAssociation ID: $eip_assoc_id"

        echo -e "\n$green \bFetching EC2 instance name..."
        ec2_instance_tag=$(aws ec2 describe-instances \
        --instance-ids $eip_instance_id \
        --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' \
        --output text)
        exit_code_check
        echo -e "\n$blue \bInstance name: $ec2_instance_tag"

        if [ $ec2_instance_tag != "$ec2_tag" ]; then
          echo -e "\n$red*** AWS free-tier allows one free EIP ***\n$yellow"
          decision_response Disassociate & release EIP, allocation ID: $e?
          [[ "$response" =~ [nN] ]] && { disassoc=false; release=false; }
        fi

        if [ "$disassoc" != false ]; then
          echo -e "\n$green \bDisassociating EIP from $ec2_instance_tag..."
          aws ec2 disassociate-address --association-id $eip_assoc_id
          exit_code_check
          unset disassoc
        else
          echo -e "\n$blue \bAssociation, ID: $eip_assoc_id remains!"
        fi

        if [ "$release" != false ]; then
          echo -e "\n$green \bReleasing EIP, allocation ID: $e..."
          aws ec2 release-address --allocation-id $e
          exit_code_check
          unset release
        else
          echo -e "\n$blue \bEIP, ID: $e remains!"
        fi
      else
        echo -e "\n$blue \bNo EC2 association found!"
      fi # end conditional: [ -n "$eip_instance_id" ]
    done # end loop: e in "${eip_ids[@]}"
  else
    echo -e "\n$blue \bNo existing EIP found!"
  fi # end conditional: [ ${#eip_ids[@]} -gt 0 ]
}

ec2_eip_create() {
  if [[ $1 != rotate ]]; then
    echo -e "\n$white \b****  EIP: Allocate & Associate  ****"
  fi

  ec2_eip_remove

  echo -e "\n$green \bAllocating new EIP..."
  eip_id=$(aws ec2 allocate-address \
    --domain vpc \
    --query AllocationId \
    --output text)
  exit_code_check

  echo -e "\n$green \bAssociating EIP with EC2 instance: $ec2_tag... \n"
  aws ec2 associate-address \
    --allocation-id $eip_id \
    --instance-id $ec2_id \
    --output table
  exit_code_check

  aced_config_update ec2_id

  echo -e "\n$green \bGetting EC2 instance $ec2_tag's new public IP address..."
  ec2_ip=$(aws ec2 describe-instances \
    --instance-ids $ec2_id \
    --query Reservations[*].Instances[*].PublicIpAddress \
    --output text)
  exit_code_check

  aced_config_update ec2_ip

  echo -e "\n$yellow \bReview EIP allocation in AWS web console: \
  \n\n$aws_con#Addresses $reset"
}
