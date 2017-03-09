#!/usr/bin/env bash

####################################################
##  filename:   ec2.sh                            ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    launch instance & initial config  ##
##  date:       03/08/2017                        ##
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



  # delete any previous launch variable
  unset launch
  #
  # startstop
  # launch
  # terminate
  # descripbe
  # can't find, shall we create one? promt'

  # get EC2 instance-id
  ec2_id=$(aws ec2 describe-instance-status | grep InstanceId | \
    awk '{gsub(/"/, ""); gsub(/,/,""); print $2}')

  echo -e "\n$yellow \bEC2 Instance Found: $ec2_id \n $green"

  # do while EC2 instance exists
  while $(aws ec2 describe-instance-status | grep -q InstanceId); do

    # select menu prompt
    PS3=$'\nEnter Task: '

    # start looping menu
    select choice in "Describe Instance" "Terminate Instance" "QUIT"; do
      case $choice in
        "Describe Instance")
          echo -e $reset ""
          aws ec2 describe-instances --output table
          echo -e $green ""
          break ;;
        "Terminate Instance")
          terminate   # invoke function to delete EC2 instance
          eip         # invoke function to delete EIP address
          break ;;
        "QUIT")
          launch=false  # abort launchInstance function
          exit 0 ;;
        *) echo -e "\n$yellow \bInvalid Option! \n $green"
          break ;;
      esac
    done
  done
}

ec2_launch() {
  #################################################################
  ####  find AWS AMI ID      ######################################
  ####  launch EC2 instance  ######################################
  #################################################################

  echo -e "\n$yellow \b\
  Find an ami ID using AWS Management Console... \n\b \
   - Filter on "Free tier only" using radio box in left tab \n\b \
   - Look for Ubuntu Server\n\b \
   - Copy ami ID, e.g. ami-539ac933\n"

  # wait 5 seconds before opening browser
  sleep 5

  # open the AWS Management Console using default browser
  params=$region#LaunchInstanceWizard
  open https://us-west-1.console.aws.amazon.com/ec2/v2/home?region=$params

  # enter AWS EC2 machine image (ami) id
  read -rp $'\nEnter aws ami id: ' ec2_ami_id

  # launch instance; add security group; attach EBS volume for storage
  echo -e "\n$green \bLaunching AWS EC2 Instance..."
  ec2_ins_id=$(aws ec2 run-instances \
    --image-id $ec2_ami_id \
    --count 1 \
    --instance-type t2.micro \
    --key-name $key \
    --security-groups $sec_group \
    --block-device-mappings "[{ \
    \"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":30}}]" \
    --output text --query 'Instances[*].InstanceId')

  aws ec2 wait instance-running --instance-ids "$ec2_ins_id"

  # prompt for tag key/value
  read -rp 'Enter name for your new instance: ' ec2_name

  # add tags
  aws ec2 create-tags --resources "$ec2_ins_id" \
    --tags Key=Name,Value="$ec2_name"

  # list new instance
  aws ec2 describe-instances --instance-ids $ec2_ins_id --output table
}

ssh_alias() {
  #################################################################
  ####  create ssh connection alias  ##############################
  #################################################################

  # get ID address
  ec2_ip=$(aws ec2 describe-instances \
    --instance-ids $ec2_ins_id \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text)

  # input cloud host alias
  read -rp $'\nEnter ssh alias for cloud host: ' ssh_host

  # input default user for cloud host
  read -rp $'\nEnter default user for cloud host: ' os_user_default

  # input private key filename
  read -rp $'\nEnter private key filename: ' key_identity

  # add ssh connection alias to ssh client config
  echo -e "\n$green \bAdding ssh alias $ssh_alias..."
  echo -e "\nHost $ssh_alias\n  HostName $eip_address\n  User \
    $os_user_default\n  Port 22\n  IdentityFile ~/.ssh/$key_identity" \
    >> $ssh_cfg

  # list new ssh connection alias
  echo $blue && cat $ssh_config/config
}

remote_user() {
  #################################################################
  ####  create new user on EC2 instance   #########################
  ####  configure user for remote access  #########################
  #################################################################

  # input username
  read -rp $'\nEnter username for new user: ' os_user

  # input password
  read -sp $'\nEnter password for new user: ' os_user_pass

  # create new user with disabled login & no finger info
  echo -e "\n$green \bCreating new user: $os_user..."
  ssh aws "sudo adduser --disabled-login --gecos '' $os_user"

  # set new user password
  echo -e "\n$green \bSetting new user password: $os_user..."
  ssh aws "echo $os_user:$os_user_pass | sudo chpasswd"

  # add new user to sudo group, which has sudo permissions via /etc/sudoers
  echo -e "\n$green \bAdd new user to sudo group for elevated privileges..."
  ssh aws "sudo usermod -aG sudo $os_user"

  # list new user
  ssh -t aws "tput setaf 33; id $os_user; tput sgr0"

  # push public key to new user
  # set ownership of directory and contents to new user
  # set permissions on parent directory to 700 (owner: read/write/exectute)
  # set permissions on authorized_keys to 600 (owner: read/write)
  echo -e "\n$green \bPushing public key to new user: $os_user..."
  cat ~/src/config/keys/$key_identity.pub | ssh aws " \
    sudo mkdir /home/$os_user/.ssh && \
    sudo tee /home/$os_user/.ssh/authorized_keys > /dev/null && \
    sudo chown -R $os_user:$os_user /home/$os_user/.ssh && \
    sudo chmod =,u+rwx /home/$os_user/.ssh && \
    sudo chmod =,u+rw ~/.ssh/authorized_keys"

  # cat pushed public key
  ssh -t aws "tput setaf 33; sudo cat \
    /home/$os_user/.ssh/authorized_keys; tput sgr0"
}

eip() {
  #################################################################
  ####  check for existing elastic ip (EIP)  ######################
  ####  get elastic ip (EIP)                 ######################
  ####  assign EIP to EC2 instance           ######################
  #################################################################

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
      --instance-id $ec2_ins_id \
      --allocation-id $eip_id \
      --output table

    # get EIP octets
    eip=$(aws ec2 describe-instances \
      --instance-ids $ec2_ins_id \
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
  #################################################################
  ####  terminate AWS EC2 instance  ###############################
  #################################################################

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
