#!/usr/bin/env bash

####################################################
##  filename:   ec2.sh                            ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    launch instance & initial config  ##
##  date:       03/10/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

ec2() {
  ec2_launch
  ec2_ssh_alias
  ec2_user_create
  ec2_eip
  ec2_ssh_alias
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

  aws ec2 wait instance-running --instance-ids "$ec2_id" & show_active

  echo -e "\n$green \bAdding name tag: $ec2_tag to $ec2_id..."
  aws ec2 create-tags --resources "$ec2_id" --tags Key=Name,Value="$ec2_tag" &
  show_active

  echo -e "\n$green \bStoring instance ID for future EC2 tasks..."
  update_config ec2_id
}

ec2_ssh_alias() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  SSH: Connection Alias Creation  XXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # get IP address
  ec2_ip=$(aws ec2 describe-instances \
    --instance-ids $ec2_id \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text)

  # add ssh connection alias to ssh client config
  echo -e "\n$green \bAdding ssh alias $ssh_alias..."
  echo -e "\nHost $ssh_alias\n  HostName $eip_address\n  User \
    $ec2_default_user\n  Port 22\n  IdentityFile ~/.ssh/$ssh_keypair" \
    >> $ssh_config
  return_check
}

ec2_user_create() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: New User Creation  XXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # create new user with disabled login & no finger info
  echo -e "\n$green \bCreating new user: $ec2_user..."
  ssh aed "sudo adduser --disabled-login --gecos '' $ec2_user"

  # set new user password
  echo -e "\n$green \bSetting new user password: $ec2_user..."
  ssh aed "echo $ec2_user:$ec2_user_pass | sudo chpasswd"

  # add new user to sudo group, which has sudo permissions via /etc/sudoers
  echo -e "\n$green \bAdd new user to sudo group for elevated privileges..."
  ssh aed "sudo usermod -aG sudo $ec2_user"

  # list new user
  ssh -t aws "tput setaf 33; id $ec2_user; tput sgr0"

  # push public key to new user
  # set ownership of directory and contents to new user
  # set permissions on parent directory to 700 (owner: read/write/exectute)
  # set permissions on authorized_keys to 600 (owner: read/write)
  echo -e "\n$green \bPushing public key to new user: $ec2_user..."
  cat ~/src/config/keys/$key_identity.pub | ssh aed " \
    sudo mkdir /home/$ec2_user/.ssh && \
    sudo tee /home/$ec2_user/.ssh/authorized_keys > /dev/null && \
    sudo chown -R $ec2_user:$ec2_user /home/$ec2_user/.ssh && \
    sudo chmod =,u+rwx /home/$ec2_user/.ssh && \
    sudo chmod =,u+rw ~/.ssh/authorized_keys"

  # cat pushed public key
  ssh -t aws "tput setaf 33; sudo cat \
    /home/$ec2_user/.ssh/authorized_keys; tput sgr0"
}

ec2_eip() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EIP: IP Address Obtain & Associate  XX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # check for EIP
  if $(aws ec2 describe-addresses | grep -q AllocationId); then

    echo -e "\n$yellow \b Existing EIP Address Found... \n $reset"
    aws ec2 describe-addresses --output table
    echo -e "$green\n"

    # prompt to release
    read -rp "Release EIP? [Y/N] " response

    # check for response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$green \bReleasing EIP address..."
      aws ec2 release-address --allocation-id \
        $(aws ec2 describe-addresses \
        --query 'Addresses[*].AllocationId' \
        --output text)
      echo -e "\n$blue \bEIP Address Released!"
    fi

  else
    # obtain elastic ip address (EIP) & get allocation-id
    echo -e "\n$green \bObtaining Elastic IP address (EIP)... \n"
    eip_id=$(aws ec2 allocate-address --output text | awk '{print $1}')

    # list new EIP
    aws ec2 describe-addresses \
      --filter=Name=allocation-id,Values=$eip_id \
     --output table

    # assign EIP to EC2 instance
    echo -e "\n$green \bAssociating EIP with EC2 instance... \n"
    aws ec2 associate-address \
      --instance-id $ec2_id \
      --allocation-id $eip_id \
      --output table

    # get EIP octets
    eip=$(aws ec2 describe-instances \
      --instance-ids $ec2_id \
      --query 'Reservations[*].Instances[*].PublicIpAddress' \
      --output text)

    # update IP address in ssh connection alias
    echo -e "\n$green \bUpdating IP address in ssh connection alias..."
    sed -i '' "s/HostName $ec2_ip/HostName $eip/" ~/.ssh/config
    ec2_ip=$eip

    # list updated ssh connection alias
    echo $blue && cat $ssh_cfg
  fi
}

terminate(){
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Instance Termination  XXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e $yellow ""
  read -rp "Terminate AWS EC2 Instance? [Y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then

    # terminate instance
    echo -e "$green \bTerminating AWS EC2 Instance... $reset"
    aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances \
      --region us-west-1 \
      --query 'Reservations[].Instances[].[InstanceId]' \
      --output text)

    # $green light launchInstance function
    launch=true
  fi
}

status() {
  aws ec2 describe-instance-status --output table # EC2 instance status
}
stop() {
  aws ec2 # EC2 instance
}
reboot() {
  aws ec2 # EC2 instance
}
