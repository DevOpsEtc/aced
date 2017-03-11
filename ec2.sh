#!/usr/bin/env bash

####################################################
##  filename:   ec2.sh                            ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    launch instance & initial config  ##
##  date:       03/10/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

# eip             # check EIP; release; allocate; associate
# ssh_alias        # create; update ssh connection alias
# remote_user      # create new EC2 remote user

ec2_temp() {
  ##########################################################
  ####  check for existing EC2 instances  ##################
  ####  check for existing EIP address    ##################
  ##########################################################

  # get EC2 instance-id
  ec2_id=$(aws ec2 describe-instance-status | grep InstanceId | \
    awk '{gsub(/"/, ""); gsub(/,/,""); print $2}')

  echo -e "\n$yellow \bEC2 Instance Found: $ec2_id \n $green"
}
ec2_launch() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Instance Launch  XXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # launch instance; add security group; attach EBS volume for storage
  echo -e "\n$green \bLaunching AWS EC2 Instance..."
  ec2_id=$(aws ec2 run-instances \
    --image-id $ec2_ami_id \
    --count 1 \
    --instance-type t2.micro \
    --key-name $ec2_key \
    --security-groups $ec2_group \
    --block-device-mappings "[{ \
    \"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":30}}]" \
    --output text --query 'Instances[*].InstanceId')

  aws ec2 wait instance-running --instance-ids "$ec2_id"

  # add tags
  aws ec2 create-tags --resources "$ec2_id" \
    --tags Key=Name,Value="$ec2_tag"

  # list new instance
  aws ec2 describe-instances --instance-ids $ec2_id --output table
}

ssh_alias() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  SSH: Connection Alias Creation  XXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # get ID address
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

remote_user() {
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

eip() {
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
