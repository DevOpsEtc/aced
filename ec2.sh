#!/usr/bin/env bash

####################################################
##  filename:   ec2.sh                            ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    launch instance & initial config  ##
##  date:       03/01/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

# aed_eip             # check EIP; release; allocate; associate
# aed_ssh_alias        # create; update ssh connection alias
# aed_remote_user      # create new EC2 remote user

aed_ec2_temp() {
  ##########################################################
  ####  check for existing EC2 instances  ##################
  ####  check for existing EIP address    ##################
  ##########################################################



  # delete any previous launch variable
  unset aed_launch
  #
  # startstop
  # launch
  # terminate
  # descripbe
  can't find, shall we create one? promt'

  # get EC2 instance-id
  aed_ec2_id=$(aws ec2 describe-instance-status | grep InstanceId | \
    awk '{gsub(/"/, ""); gsub(/,/,""); print $2}')

  echo -e "\n$aed_ylw \bEC2 Instance Found: $aed_ec2_id \n $aed_grn"

  # do while EC2 instance exists
  while $(aws ec2 describe-instance-status | grep -q InstanceId); do

    # select menu prompt
    PS3=$'\nEnter Task: '

    # start looping menu
    select choice in "Describe Instance" "Terminate Instance" "QUIT"; do
      case $choice in
        "Describe Instance")
          echo -e $aed_rst ""
          aws ec2 describe-instances --output table
          echo -e $aed_grn ""
          break ;;
        "Terminate Instance")
          aed_terminate   # invoke function to delete EC2 instance
          aed_eip         # invoke function to delete EIP address
          break ;;
        "QUIT")
          aed_launch=false  # abort launchInstance function
          exit 0 ;;
        *) echo -e "\n$aed_ylw \bInvalid Option! \n $aed_grn"
          break ;;
      esac
    done
  done
}

aed_ec2_launch() {
  #################################################################
  ####  find AWS AMI ID      ######################################
  ####  launch EC2 instance  ######################################
  #################################################################

  echo -e "\n$aed_ylw \b\
  Find an ami ID using AWS Management Console... \n\b \
   - Filter on "Free tier only" using radio box in left tab \n\b \
   - Look for Ubuntu Server\n\b \
   - Copy ami ID, e.g. ami-539ac933\n"

  # wait 5 seconds before opening browser
  sleep 5

  # open the AWS Management Console using default browser
  aed_params=$region#LaunchInstanceWizard
  open https://us-west-1.console.aws.amazon.com/ec2/v2/home?region=$aed_params

  # enter AWS EC2 machine image (ami) id
  read -p $'\nEnter aws ami id: ' aed_ec2_ami_id

  # launch instance; add security group; attach EBS volume for storage
  echo -e "\n$aed_grn \bLaunching AWS EC2 Instance..."
  aed_ec2_ins_id=$(aws ec2 run-instances \
    --image-id $aed_ec2_ami_id \
    --count 1 \
    --instance-type t2.micro \
    --key-name $aed_key \
    --security-groups $aed_sec_group \
    --block-device-mappings "[{ \
    \"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":30}}]" \
    --output text --query 'Instances[*].InstanceId')

  aws ec2 wait instance-running --instance-ids "$aed_ec2_ins_id"

  # prompt for tag key/value
  read -p 'Enter name for your new instance: ' aed_ec2_name

  # add tags
  aws ec2 create-tags --resources "$aed_ec2_ins_id" \
    --tags Key=Name,Value="$aed_ec2_name"

  # list new instance
  aws ec2 describe-instances --instance-ids $aed_ec2_ins_id --output table
}

aed_ssh_alias() {
  #################################################################
  ####  create ssh connection alias  ##############################
  #################################################################

  # get ID address
  aed_ec2_ip=$(aws ec2 describe-instances \
    --instance-ids $aed_ec2_ins_id \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text)

  # input cloud host alias
  read -p $'\nEnter ssh alias for cloud host: ' aed_ssh_host

  # input default user for cloud host
  read -p $'\nEnter default user for cloud host: ' aed_os_user_default

  # input private key filename
  read -p $'\nEnter private key filename: ' aed_key_identity

  # add ssh connection alias to ssh client config
  echo -e "\n$aed_grn \bAdding ssh alias $aed_ssh_host..."
  echo -e "\nHost $aed_ssh_host\n  HostName $aed_ec2_ip\n  User \
    $aed_os_user_default\n  Port 22\n  IdentityFile ~/.ssh/$aed_key_identity" \
    >> $aed_ssh_cfg

  # list new ssh connection alias
  echo $aed_blu && cat $aed_ssh_cfg
}

aed_remote_user() {
  #################################################################
  ####  create new user on EC2 instance   #########################
  ####  configure user for remote access  #########################
  #################################################################

  # input username
  read -p $'\nEnter username for new user: ' aed_os_user

  # input password
  read -sp $'\nEnter password for new user: ' aed_os_user_pass

  # create new user with disabled login & no finger info
  echo -e "\n$aed_grn \bCreating new user: $aed_os_user..."
  ssh aws "sudo adduser --disabled-login --gecos '' $aed_os_user"

  # set new user password
  echo -e "\n$aed_grn \bSetting new user password: $aed_os_user..."
  ssh aws "echo $aed_os_user:$aed_os_user_pass | sudo chpasswd"

  # add new user to sudo group, which has sudo permissions via /etc/sudoers
  echo -e "\n$aed_grn \bAdd new user to sudo group for elevated privileges..."
  ssh aws "sudo usermod -aG sudo $aed_os_user"

  # list new user
  ssh -t aws "tput setaf 33; id $aed_os_user; tput sgr0"

  # push public key to new user
  # set ownership of directory and contents to new user
  # set permissions on parent directory to 700 (owner: read/write/exectute)
  # set permissions on authorized_keys to 600 (owner: read/write)
  echo -e "\n$aed_grn \bPushing public key to new user: $aed_os_user..."
  cat ~/src/config/keys/$aed_key_identity.pub | ssh aws " \
    sudo mkdir /home/$aed_os_user/.ssh && \
    sudo tee /home/$aed_os_user/.ssh/authorized_keys > /dev/null && \
    sudo chown -R $aed_os_user:$aed_os_user /home/$aed_os_user/.ssh && \
    sudo chmod =,u+rwx /home/$aed_os_user/.ssh && \
    sudo chmod =,u+rw ~/.ssh/authorized_keys"

  # cat pushed public key
  ssh -t aws "tput setaf 33; sudo cat \
    /home/$aed_os_user/.ssh/authorized_keys; tput sgr0"
}

aed_eip() {
  #################################################################
  ####  check for existing elastic ip (EIP)  ######################
  ####  get elastic ip (EIP)                 ######################
  ####  assign EIP to EC2 instance           ######################
  #################################################################

  # check for EIP
  if $(aws ec2 describe-addresses | grep -q AllocationId); then

    echo -e "\n$aed_ylw \b Existing EIP Address Found... \n $aed_rst"
    aws ec2 describe-addresses --output table
    echo -e "$aed_grn\n"

    # prompt to release
    read -r -p "Release EIP? [Y/N] " aed_opt

    # check for response
    if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$aed_grn \bReleasing EIP address..."
      aws ec2 release-address --allocation-id \
        $(aws ec2 describe-addresses \
        --query 'Addresses[*].AllocationId' \
        --output text)
      echo -e "\n$aed_blu \bEIP Address Released!"
    fi

  else
    # obtain elastic ip address (EIP) & get allocation-id
    echo -e "\n$aed_grn \bObtaining Elastic IP address (EIP)... \n"
    aed_eip_id=$(aws ec2 allocate-address --output text | awk '{print $1}')

    # list new EIP
    aws ec2 describe-addresses \
      --filter=Name=allocation-id,Values=$aed_eip_id \
     --output table

    # assign EIP to EC2 instance
    echo -e "\n$aed_grn \bAssociating EIP with EC2 instance... \n"
    aws ec2 associate-address \
      --instance-id $aed_ec2_ins_id \
      --allocation-id $aed_eip_id \
      --output table

    # get EIP octets
    aed_eip=$(aws ec2 describe-instances \
      --instance-ids $aed_ec2_ins_id \
      --query 'Reservations[*].Instances[*].PublicIpAddress' \
      --output text)

    # update IP address in ssh connection alias
    echo -e "\n$aed_grn \bUpdating IP address in ssh connection alias..."
    sed -i '' "s/HostName $aed_ec2_ip/HostName $aed_eip/" ~/.ssh/config
    aed_ec2_ip=$aed_eip

    # list updated ssh connection alias
    echo $aed_blu && cat $aed_ssh_cfg
  fi
}

aed_terminate(){
  #################################################################
  ####  terminate AWS EC2 instance  ###############################
  #################################################################

  echo -e $aed_ylw ""
  read -r -p "Terminate AWS EC2 Instance? [Y/N] " aed_opt
  if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then

    # terminate instance
    echo -e "$aed_grn \bTerminating AWS EC2 Instance... $aed_rst"
    aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances \
      --region us-west-1 \
      --query 'Reservations[].Instances[].[InstanceId]' \
      --output text)

    # $aed_grn light launchInstance function
    aed_launch=true
  fi
}

aed_status() {
  aws ec2 describe-instance-status --output table # EC2 instance status
}
aed_stop() {
  aws ec2 # EC2 instance
}
aed_reboot() {
  aws ec2 # EC2 instance
}
