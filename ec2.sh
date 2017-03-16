#!/usr/bin/env bash

####################################################
##  filename:   ec2.sh                            ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    launch instance & initial config  ##
##  date:       03/15/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
####################################################

ec2() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Launch/EIP/SSH Alias/User  XX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  ec2_launch        # check EC2 instances; grab AMI; launch new EC2 instance
  ec2_eip_create    # check EIPs; allocate new EIP; associate EIP with EC2
  ssh_alias_create  # create or update existing SSH connection alias
  ec2_user_create   # check EC2 users; create new; assign to EC2 security group
  ssh_alias_create  # run 2nd time to update changed values
}

ec2_eip_rotate() {
  ec2_eip_create
  ssh_alias_create
}

ec2_keypair_rotate() {
  :
}

ec2_state_fetch() {
  ##############################################
  ####  Fetch current state of EC2 instance  ###
  ##############################################

  ec2_state=$(aws ec2 describe-instances \
    --instance-ids $ec2_id \
    --query 'Reservations[].Instances[].State.Name' \
    --output text
    )
}

ec2_status() {
  ec2_state_fetch # invoke function to fetch fresh state
  if [ $ec2_state == "running" ]; then
    aws ec2 describe-instance-status \
      --instance-ids $ec2_id \
      --output table
  else
    echo -e "\n$yellow \bDrat, can't stop $ec2_tag because it's: $ec2_state"
    return
  fi
}

ec2_start() {
  ec2_state_fetch
  if [ $ec2_state == "stopped" ]; then
    echo -e "\n$green \bStarting EC2 Instance: $ec2_tag..."
    aws ec2 start-instances --instance-ids $ec2_id
    aws ec2 wait instance-running --instance-ids "$ec2_id" &
    show_active
  else
    echo -e "\n$yellow \bDrat, can't start $ec2_tag because it's: $ec2_state"
    return
  fi
}

ec2_stop() {
  ec2_state_fetch
  if [ $ec2_state == "running" ]; then
    read -rp "Confirm stop EC2 instance: $ec2_tag? [Y/N] " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$green \bStopping EC2 Instance: $ec2_tag..."
      aws ec2 stop-instances --instance-ids $ec2_id
      aws ec2 wait instance-stopped --instance-ids "$ec2_id" &
      show_active
    fi
  else
    echo -e "\n$yellow \bDrat, can't stop $ec2_tag because it's: $ec2_state"
    return
  fi
}

ec2_reboot() {
  ec2_state_fetch
  if [ $ec2_state == "running" ]; then
      ec2_stop
      ec2_start
  else
    echo -e "\n$yellow \bDrat, can't reboot $ec2_tag because it's: $ec2_state"
    return
  fi
}

ec2_terminate() {
  ############################################################
  ####  Terminate EC2 instance using InstanceID parameter  ###
  ############################################################

  [ -z "$1" ] && echo -e "\n$yellow \bNo argument supplied!"; exit 1

  echo -e "\n$green \bTerminating Instance: $1..."
  aws ec2 terminate-instances --instance-ids "$1"
  aws ec2 wait instance-terminated --instance-ids "$1" &
  show_active
}

ec2_launch() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Instance Launch  XXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "$green \bChecking for existing EC2 instances..."
  ec2_instances=($(aws ec2 describe-instances \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text)
    )

  if [ ${#ec2_instances[@]} -gt 0 ]; then
    for i in "${ec2_instances[@]}"; do
      echo -e "\n$yellow \bEC2 instance found: $i \n"

      echo -e "\n$green \bChecking for tag name: $ec2_tag \n"
      ec2_instance_tag=$(aws ec2 describe-instances \
        --instance-ids $i \
        --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' \
        --output text)

      if [ $ec2_instance_tag == "$ec2_tag" ]; then
        echo -e "\n$yellow \bEC2 instance with tag: $ec2_tag found! \n"
        ec2_terminate $i # invoke function to terminate; pass instance-id
      else
        echo -e "\n$yellow \bNo matching tag found! \n"
      fi

      read -rp "Should we still terminate the instance: $i? [Y/N] " response
      if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        ec2_terminate $i
      else
        echo -e "\n$red \b***** Running multiple instances can push \
        \b\b\b\b\b\b\b\bfree-tier account past monthly allowances! *****"
      fi
    done
  else
    echo -e "\n$yellow \bNo EC2 instances found!"
  fi

  echo -e "$green \bFetching latest AMI ID for Ubuntu Server 16.04 LTS..."
  ami_id=$(aws ec2 describe-images \
    --region $aws_region \
    --owners $ec2_ami_owner \
    --filters \
      Name=virtualization-type,Values=hvm \
      Name=root-device-type,Values=ebs \
      Name=architecture,Values=x86_64 \
      Name=name,Values=*hvm-ssd/ubuntu-$ec2_ami_name-$ec2_ami_ver* \
    --query 'sort_by(Images, &Name)[-1].ImageId' \
    --output text \
    )

  ami_name=$(aws ec2 describe-images --image-ids $ami_id \
    --query "Images[*].Name" \
    --output text)

  echo -e "\n$blue \bLatest AMI: $ami_id \n$ami_name $reset"

  echo -e "\n$green \bLaunching AWS EC2 Instance $ami_id..."
  ec2_id=$(aws ec2 run-instances \
    --image-id $ami_id \
    --count 1 \
    --instance-type t2.micro \
    --key-name $ssh_key_public \
    --security-groups $ec2_group \
    --block-device-mappings "[{ \
    \"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":30}}]" \
    --query 'Instances[*].InstanceId' \
    --output text
    )
  return_check

  aws ec2 wait instance-running --instance-ids "$ec2_id" &
  show_active

  echo -e "\n$green \bAdding name tag: $ec2_tag to $ec2_id..."
  aws ec2 create-tags --resources "$ec2_id" --tags Key=Name,Value="$ec2_tag" &
  show_active

  echo -e "\n$green \bPushing EC2 instance ID: $ec2_id => ACED config... \n"
  update_config ec2_id
  return_check

  echo -e "\n$yellow \bReview EC2 instances in AWS web console:"
  echo -e "\n$yellow \b$aws_con#Instances"
}

ec2_eip_create() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: EIP Address Allocate & Associate  XX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bChecking for existing EIPs..."
  eips=($(aws ec2 describe-addresses \
    --query Addresses[*].AllocationId \
    --output text)
    )

  if [ ${#eips[@]} -gt 0 ]; then
    for e in "${eips[@]}"; do
      echo -e "\n$blue \bFound EIP: $e"

      echo -e "\n$green \bChecking EIP's EC2 instance association..."
      eip_instance_id=$(aws ec2 describe-addresses \
      --allocation-ids $e \
      --query Addresses[*].InstanceId \
      --output text)

      eip_assoc_id=$(aws ec2 describe-addresses \
      --allocation-ids $e \
      --query Addresses[*].AssociationId \
      --output text)

      if [ -n "$eip_instance_id" ]; then
        echo -e "\n$blue \bAssociated with EC2 instance: $eip_instance_id"

        echo -e "\n$green \bChecking for instance name: $ec2_tag..."
        ec2_instance_tag=$(aws ec2 describe-instances \
          --instance-ids $ec2_id \
          --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' \
          --output text)

        if [ $ec2_instance_tag == "$ec2_tag" ]; then
          echo -e "\n$blue \bInstance name matches: $ec2_tag"
        else
          echo -e "\n$yellow \bNo match, instance name: $ec2_instance_tag"
          echo -e "\n$red \b*** AWS free-tier allows one free EIP ***\n$yellow"

          read -rp "Want to disassociate & release EIP: $e? [Y/N] " response

          if [[ "$response" =~ ^([nN][oO]|[nN])+$ ]]; then
            eip_disassociate=false
            eip_release=false
          fi
        fi

        if [ "$eip_disassociate" != false ]; then
          echo -e "\n$green \bDisassociating EIP from $ec2_tag..."
          aws ec2 disassociate-address --association-id $eip_assoc_id
          # return_check
        else
          echo -e "\n$yellow \bExisting EIP untouched!"
        fi
      else
        echo -e "\n$yellow \bNo EC2 association found!"
      fi

      if [ "$eip_release" != false ]; then
        echo -e "\n$green \bReleasing EIP..."
        aws ec2 release-address --allocation-id $e
        return_check
      fi
    done
  fi

  echo -e "\n$green \bAllocating new EIP..."
  eip_id=$(aws ec2 allocate-address \
    --domain vpc \
    --query AllocationId \
    --output text
    )
  return_check

  echo -e "\n$green \bAssociating EIP with EC2 instance: $ec2_tag... \n"
  aws ec2 associate-address \
    --allocation-id $eip_id \
    --instance-id $ec2_id \
    --output table
  return_check

  echo -e "\n$green \bGetting EC2 instance $ec2_tag's new public IP address..."
  ec2_ip=$(aws ec2 describe-instances \
    --instance-ids $ec2_id \
    --query Reservations[*].Instances[*].PublicIpAddress \
    --output text)
  return_check

  echo -e "\n$green \bPushing EIP address: $ec2_ip => ACED config... "
  update_config ec2_ip
  return_check

  echo -e "\n$yellow \bYou can review EIP allocation in the AWS web console: \
  \n$aws_con#Addresses $reset"
}

ssh_alias_create() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  SSH: Connection Alias Creation  XXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bChecking for existing SSH alias: $ssh_alias..."
  if ! grep -wq "Host $ssh_alias" ~/.ssh/config; then
    echo -e "\n$blue \bSSH connection alias not found: $ssh_alias"
    echo -e "\n$green \bCreating SSH connection alias: $ec2_tag..."

    echo -e "\n$green \bPushing SSH connection values to ACED config..."
    ssh_hostname=$ec2_ip
    ssh_user=$ec2_user_def
    ssh_port=$ec2_ssh_port_def
    update_config ssh_hostname ssh_user ssh_port

    echo -e " \
    \n############### $ssh_alias ###############\
    \nHost $ssh_alias \
    \n  HostName $ssh_hostname \
    \n  User $ssh_user \
    \n  Port $ssh_port \
    \n  IdentityFile ~/.ssh/$ssh_key_private \
    \n############### $ssh_alias ###############" \
    >> ~/.ssh/config
    return_check
  else
    echo -e "\n$blue \bSSH connection alias found: $ssh_alias"
    echo -e "\n$green \bUpdating SSH connection alias: $ssh_alias..."
    sed -i '' \
      -e "s/HostName $ssh_hostname/HostName $ec2_ip/" \
      -e "s/User $ssh_user/User $ec2_user/" \
      -e "s/Port $ssh_port/Port $ec2_ssh_port/" \
      ~/.ssh/config

    echo -e "\n$green \bPushing updated SSH connection values to ACED config..."
    ssh_hostname=$ec2_ip
    ssh_user=$ec2_user
    ssh_port=$ec2_ssh_port
    update_config ssh_hostname ssh_user ssh_port
  fi

  echo -e "\n$green \bTesting SSH alias: $ssh_alias..."
  ssh $ssh_alias "uname --all"
  return_check

  echo -e "\n$yellow \bCan now connect to EC2 instance via \$ ssh $ssh_alias"
}

ec2_user_create() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: New User Creation  XXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bCreating EC2 user: $ec2_user..."
  ssh $ssh_alias "sudo adduser --disabled-login --gecos '' $ec2_user"

  echo -e "\n$green \bSetting new user password: $ec2_user..."
  ssh $ssh_alias "echo $ec2_user:$ec2_temp_pass | sudo chpasswd"

  echo -e "\n$green \bAdding $ec2_user to sudo group (elevated privileges)..."
  ssh $ssh_alias "sudo usermod -aG sudo $ec2_user"

  echo -e "\n$green \bListing $ec2_user..."
  ssh -t $ssh_alias "tput setaf 33; id $ec2_user; tput sgr0"

  echo -e "\n$green \bPushing public key to $ec2_user..."
  cat $aced_keys/$ssh_key_public | ssh $ssh_alias " \
    sudo mkdir -p /home/$ec2_user/.ssh \
    && sudo tee /home/$ec2_user/.ssh/authorized_keys > /dev/null"

  echo -e "\n$green \bChanging ownership of SSH config directory..."
  ssh $ssh_alias "sudo chown -R $ec2_user:$ec2_user /home/$ec2_user/.ssh"

  echo -e "\n$green \bChanging SSH file permissions..."
  ssh $ssh_alias "sudo chmod =,u+rwx /home/$ec2_user/.ssh \
  && sudo chmod =,u+rw ~/.ssh/authorized_keys"

  echo -e "\n$green \bPushing public key to SSH authorized keys..."
  ssh -t $ssh_alias "tput setaf 33; sudo cat \
    /home/$ec2_user/.ssh/authorized_keys; tput sgr0"
}
