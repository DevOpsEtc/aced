#!/usr/bin/env bash

#########################################################
##  filename:     ec2.sh														 	 ##
##  path:         ~/src/deploy/cloud/aws/						   ##
##  purpose:      launch instance & initial config     ##
##  date:         02/20/2017													 ##
##  repo:         https://github.com/DevOpsEtc/deploy	 ##
##	source:		    $ . ~/src/deploy/cloud/aws/ec2.sh    ##
#########################################################

# aed_eip             # check EIP; release; allocate; associate
# aed_sshAlias        # create; update ssh connection alias
# aed_remoteUser      # create new EC2 remote user


aed_Ec2Menu() {
  echo "EC2 Tasks: launch|describe|terminate|start|stop|reboot|show IP"
}

aed_Ec2temp() {
  ##########################################################
  ####  check for existing EC2 instances  ##################
  ####  check for existing EIP address    ##################
  ##########################################################



  # delete any previous launch variable
  unset AED_LAUNCH
  #
  # startstop
  # launch
  # terminate
  # descripbe
  can't find, shall we create one? promt'

  # get EC2 instance-id
  ec2Id=$(aws ec2 describe-instance-status | grep InstanceId | \
    awk '{gsub(/"/, ""); gsub(/,/,""); print $2}')

  echo -e "\n$yellow \bEC2 Instance Found: $ec2Id \n $green"

  # do while EC2 instance exists
  while $(aws ec2 describe-instance-status | grep -q InstanceId); do

    # select menu prompt
    PS3=$'\nEnter Task: '

    # start looping menu
    select choice in "Describe Instance" "Terminate Instance" "QUIT"; do
      case $choice in
        "Describe Instance")
          echo -e $rs ""
          aws ec2 describe-instances --output table
          echo -e $green ""
          break ;;
        "Terminate Instance")
          aed_terminate   # call function to delete EC2 instance
          aed_eip         # call function to delete EIP address
          break ;;
        "QUIT")
          AED_LAUNCH=false  # abort launchInstance function
          exit 0 ;;
        *) echo -e "\n$yellow \bInvalid Option! \n $green"
          break ;;
      esac
    done
  done
}

aed_Ec2Launch() {
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
  read -p $'\nEnter aws ami id: ' aws_ami_id

  # launch instance; add security group; attach EBS volume for storage
  echo -e "\n$green \bLaunching AWS EC2 Instance..."
  ec2InsId=$(aws ec2 run-instances --image-id $aws_ami_id --count 1 \
   --instance-type t2.micro --key-name $deployKey --security-groups \
   $deploySecGroup --block-device-mappings "[{ \
   \"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":30}}]" \
   --output text --query 'Instances[*].InstanceId')

  aws ec2 wait instance-running --instance-ids "$ec2InsId"

  # prompt for tag key/value
  read -p 'Enter name for your new instance: ' deployName

  # add tags
  aws ec2 create-tags --resources "$ec2InsId" \
    --tags Key=Name,Value="$deployName"

  # list new instance
  aws ec2 describe-instances --instance-ids $ec2InsId --output table
}

aed_sshAlias() {
  #################################################################
  ####  create ssh connection alias  ##############################
  #################################################################

  # get ID address
  deployIp=$(aws ec2 describe-instances --instance-ids $ec2InsId \
    --output text --query 'Reservations[*].Instances[*].PublicIpAddress')

  # input cloud host alias
  read -p $'\nEnter ssh alias for cloud host: ' deployHost

  # input default user for cloud host
  read -p $'\nEnter default user for cloud host: ' deployDefaultUser

  # input private key filename
  read -p $'\nEnter private key filename: ' deployIdentity

  # add ssh connection alias to ssh client config
  echo -e "\n$green \bAdding ssh alias $deployHost..."
  echo -e "\nHost $deployHost\n  HostName $deployIp\n  User \
    $deployDefaultUser\n  Port 22\n  IdentityFile ~/.ssh/$deployIdentity" \
    >> ~/.ssh/config2

  # list new ssh connection alias
  echo $blue && cat ~/.ssh/config
}

aed_remoteUser() {
  #################################################################
  ####  create new user on EC2 instance   #########################
  ####  configure user for remote access  #########################
  #################################################################

  # input username
  read -p $'\nEnter username for new user: ' deployUser

  # input password
  read -sp $'\nEnter password for new user: ' deployUserPass

  # create new user with disabled login & no finger info
  echo -e "\n$green \bCreating new user: $deployUser..."
  ssh aws "sudo adduser --disabled-login --gecos '' $deployUser"

  # set new user password
  echo -e "\n$green \bSetting new user password: $deployUser..."
  ssh aws "echo $deployUser:$deployUserPass | sudo chpasswd"

  # add new user to sudo group; sudo group granted sudo access via /etc/sudoers
  echo -e "\n$green \bAdd new user to sudo group for elevated privileges..."
  ssh aws "sudo usermod -aG sudo $deployUser"

  # list new user
  ssh -t aws "tput setaf 33; id $deployUser; tput sgr0"

  # push public key to new user
  # set ownership of directory and contents to new user
  # set permissions on parent directory to 700 (owner: read/write/exectute)
  # set permissions on authorized_keys to 600 (owner: read/write)
  echo -e "\n$green \bPushing public key to new user: $deployUser..."
  cat ~/src/config/keys/$deployIdentity.pub | ssh aws " \
    sudo mkdir /home/$deployUser/.ssh && \
    sudo tee /home/$deployUser/.ssh/authorized_keys > /dev/null && \
    sudo chown -R $deployUser:$deployUser /home/$deployUser/.ssh && \
    sudo chmod =,u+rwx /home/$deployUser/.ssh && \
    sudo chmod =,u+rw ~/.ssh/authorized_keys"

  # cat pushed public key
  ssh -t aws "tput setaf 33; sudo cat /home/$deployUser/.ssh/authorized_keys; \
   tput sgr0"
}

aed_eip() {
  #################################################################
  ####  check for existing elastic ip (EIP)  ######################
  ####  get elastic ip (EIP)                 ######################
  ####  assign EIP to EC2 instance           ######################
  #################################################################

  # check for EIP
  if $(aws ec2 describe-addresses | grep -q AllocationId); then

    echo -e "\n$yellow \b Existing EIP Address Found... \n $rs"
    aws ec2 describe-addresses --output table
    echo -e "$green\n"

    # prompt to release
    read -r -p "Release EIP? [Y/N] " response

    # check for response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      echo -e "\n$green \bReleasing EIP address..."
      aws ec2 release-address --allocation-id \
        $(aws ec2 describe-addresses \
        --output text \
        --query 'Addresses[*].AllocationId')
      echo -e "\n$blue \bEIP Address Released!"
    fi

  else
    # obtain elastic ip address (EIP) & get allocation-id
    echo -e "\n$green \bObtaining Elastic IP address (EIP)... \n"
    elasticIpId=$(aws ec2 allocate-address --output text | awk '{print $1}')

    # list new EIP
    aws ec2 describe-addresses --filter=Name=allocation-id,Values=$elasticIpId \
     --output table

    # assign EIP to EC2 instance
    echo -e "\n$green \bAssociating EIP with EC2 instance... \n"
    aws ec2 associate-address --instance-id $ec2InsId \
      --allocation-id $elasticIpId --output table

    # get EIP octets
    elasticIp=$(aws ec2 describe-instances --instance-ids $ec2InsId \
      --output text --query 'Reservations[*].Instances[*].PublicIpAddress')

    # update IP address in ssh connection alias
    echo -e "\n$green \bUpdating IP address in ssh connection alias..."
    sed -i '' "s/HostName $deployIp/HostName $elasticIp/" ~/.ssh/config
    deployIp=$elasticIp

    # list updated ssh connection alias
    echo $blue && cat ~/.ssh/config
  fi
}

aed_terminate(){
  #################################################################
  ####  terminate AWS EC2 instance  ###############################
  #################################################################

  echo -e $yellow ""
  read -r -p "Terminate AWS EC2 Instance? [Y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then

    # terminate instance
    echo -e "$green \bTerminating AWS EC2 Instance... $rs"
    aws ec2 terminate-instances --instance-ids \
      $(aws ec2 describe-instances \
      --region us-west-1 --query \
      'Reservations[].Instances[].[InstanceId]' \
      --output text)

    # green light launchInstance function
    launch=true
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
