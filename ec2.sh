#!/usr/bin/env bash

#####################################################
##  filename:   ec2.sh                             ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    launch instance & initial config   ##
##  date:       06/10/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

ec2() {
  echo -e "\n$white \b****  EC2: Install Tasks  ****"
  ec2_launch           # check existing; grab AMI; launch new instance
  ec2_eip_create       # check existing; allocate new; associate with EC2
  ec2_eip_fetch        # fetch EIP address
  ssh_alias_create     # check existing; create/update connection alias
  known_host_add       # add EC2 host in known_host
  aced_cfg_push ec2_ip # push updated IP to config
}

ec2_connect() {
  ec2_state # check current state of $aced_nm
  [[ "$state" != "Running" ]] && { echo -e "\n$state_msg"; return; }

  ip_fetch match  # fetch fresh localhost public IP & compare to last
  if [ "$lip_last" != "$localhost_ip/32" ]; then
    echo -e "\n$yellow \bMismatched current/last known: localhost IP!"
    ec2_rule_add lip_update # add ingress rule for new IP; revoke old
    aced_cfg_push localhost_ip
  fi

  ec2_eip_fetch last  # fetch fresh EC2 public IP & compare to last
  if [ "$ec2_ip_last" != "$ec2_ip" ]; then
    echo -e "\n$yellow \bMismatched current/last known: EC2 EIP!"
    ec2_eip_rotate mismatch
  fi

  echo -e "\n$green \bRemote: waiting on SSH port to accept connections... "
  ec2_eip_fetch silent # fetch current EIP
  aws_waiter SSH silent &
  activity_show

  echo -e "$yellow \bConnecting to EC2 instance: $ec2_tag... \n$reset"
  ssh $ssh_alias  # ssh connection to EC2 instance

  [[ "$1" == "menu" ]] \
    && read -n 1 -s -p "$yellow""Press any key to continue "; clear
}

ec2_eip_create() {
  if [ "$1" != "rotate" ] || [  ]; then
    echo -e "\n$white \b****  EIP: Allocate & Associate  ****"
  fi

  ec2_eip_remove

  echo -e "\n$green \bAllocating new EIP..."
  eip_id=$(aws ec2 allocate-address \
    --domain vpc \
    --query AllocationId \
    --output text)
  cmd_check

  aced_cfg_push ec2_id # push EC2 instance Id to ACED config

  echo -e "\n$green \bAssociating EIP with EC2 instance: $ec2_tag... \n$reset"
  aws ec2 associate-address \
    --allocation-id $eip_id \
    --instance-id $ec2_id \
    --output table
  cmd_check

  if [ "$1" != "rotate" ]; then
    echo -e "\n$yellow \bReview EIP details in the AWS web console: \n \
      \n$gray \b$aws_con#Addresses $reset"
  fi
}

ec2_eip_fetch() {
  if [ "$1" == "last" ] || [ "$1" == "silent" ] || [ "$1" == "ls" ]; then
    # strip any leading zeros from IP octets to prevent potential errors
    ec2_ip_last=$(echo $ec2_ip \
      | awk -F'[.]' '{a=$1+0; b=$2+0; c=$3+0; d=$4+0; print a"."b"."c"."d}')
    [[ "$1" == "ls" ]] && { echo -e "\n$blue \b$ec2_ip_last"; return; }
    [[ "$1" != "last" ]] && return # bail now if matching args passed
 fi

  echo -e "\n$green \bFetching public IP address for EC2 instance: $ec2_tag..."
  ec2_ip=$(aws ec2 describe-instances \
    --instance-ids $ec2_id \
    --query Reservations[*].Instances[*].PublicIpAddress \
    --output text)
  cmd_check
}

ec2_eip_remove() {
  echo -e "\n$green \bChecking for existing EIPs..."
  eip_ids=($(aws ec2 describe-addresses \
    --query Addresses[*].AllocationId \
    --output text)
  )
  cmd_check

  if [ ${#eip_ids[@]} -gt 0 ]; then
    for e in "${eip_ids[@]}"; do
      echo -e "\n$blue \bFound EIP, allocation ID: $e"
      echo -e "\n$green \bChecking for EC2 instance association..."
      eip_instance_id=$(aws ec2 describe-addresses \
        --allocation-ids $e \
        --query Addresses[*].InstanceId \
        --output text)
      cmd_check

      if [ -n "$eip_instance_id" ]; then
        echo -e "\n$blue \bAssociated with instance ID: $eip_instance_id"
        echo -e "\n$green \bFetching EC2 association ID..."
        eip_assoc_id=$(aws ec2 describe-addresses \
          --allocation-ids $e \
          --query Addresses[*].AssociationId \
          --output text)
        cmd_check
        echo -e "\n$blue \bAssociation ID: $eip_assoc_id"

        echo -e "\n$green \bFetching EC2 instance name..."
        ec2_instance_tag=$(aws ec2 describe-instances \
          --instance-ids $eip_instance_id \
          --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' \
          --output text)
        cmd_check
        echo -e "\n$blue \bInstance name: $ec2_instance_tag"

        if [ $ec2_instance_tag != "$ec2_tag" ]; then
          echo -e "\n$red*** AWS free-tier allows one free EIP ***\n$yellow"
          decision_response Disassociate & release EIP, allocation ID: $e?
          [[ "$response" =~ [nN] ]] && { disassoc=false; release=false; }
        fi

        if [ "$disassoc" != false ]; then
          echo -e "\n$green \bDisassociating EIP from $ec2_instance_tag..."
          aws ec2 disassociate-address --association-id $eip_assoc_id
          cmd_check
          unset disassoc
        else
          echo -e "\n$blue \bAssociation, ID: $eip_assoc_id remains!"
        fi

        if [ "$release" != false ]; then
          echo -e "\n$green \bReleasing EIP, allocation ID: $e..."
          aws ec2 release-address --allocation-id $e
          cmd_check
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
} # end func: ec2_eip_remove

ec2_eip_rotate() {
  if [ "$1" != "mismatch" ]; then
    ec2_state # check state; bail if not running
    [[ "$state" != "Running" ]] && { echo -e "\n$state_msg"; return; }

    notify eip_gist  # show warning
    decision_response Continue rotating EIP?
    [[ "$response" =~ [nN] ]] && exit 1
    ec2_eip_create rotate   # remove ACED EIP; allocate & associate new EIP
  fi
  ec2_eip_fetch last        # fetch old and new EIP address
  ssh_alias_create update   # update ssh connection alias with new IP
  known_host_add update     # update EC2 host in known_host
  notify eip                # show info RE: DNS host records
  aced_cfg_push ec2_ip      # push updated IP to config
  read -n 1 -s -p $'\n'"$yellow""Press any key to continue "; clear
}

ec2_launch() {
  echo -e "\n$white \b****  EC2: Instance Launch  ****"

  if [ "$1" != "redo" ]; then
    echo -e "\n$green \bChecking for existing EC2 instances..."
    ec2_instances=($(aws ec2 describe-instances \
      --filters "Name=instance-state-name,Values= \
      pending,running,shutting-down,stopping,stopped" \
      --query 'Reservations[*].Instances[*].InstanceId' \
      --output text)
    )
    cmd_check

    if [ ${#ec2_instances[@]} -gt 0 ]; then
      for i in "${ec2_instances[@]}"; do
        echo -e "\n$blue \bEC2 instance found: $i"

        echo -e "\n$green \bChecking for tag name: $ec2_tag"
        ec2_instance_tag=$(aws ec2 describe-instances \
          --instance-ids "$i" \
          --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' \
          --output text)
        cmd_check

        if [ "$ec2_instance_tag" == "$ec2_tag" ]; then
          echo -e "\n$blue \bEC2 instance with tag: $ec2_tag found!"
          ec2_terminate "$i" # invoke func: terminate; pass instance-id
        else
          echo -e "\n$blue \bNo matching tag found!"

          notify instance

          decision_response Terminate instance: $i?
          [[ "$response" =~ [yY] ]] && ec2_terminate "$i"
        fi
      done
    else
      echo -e "\n$blue \bNo EC2 instances found!"
    fi
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
  cmd_check
  echo -e "\n$blue \bLatest AMI ID: $ami_id"

  echo -e "\n$green \bFetching AMI's name..."
  ami_name=$(aws ec2 describe-images --image-ids $ami_id \
    --query "Images[*].Name" \
    --output text)
  cmd_check
  echo -e "\n$blue \bAMI's name: $ami_name"

  echo -e "\n$green \bLaunching EC2 Instance Id: $ami_id..."
  ec2_id=$(aws ec2 run-instances \
    --image-id $ami_id \
    --count 1 \
    --instance-type $aws_type \
    --key-name $ssh_key_public \
    --security-groups $ec2_group \
    --block-device-mappings "[{ \
      \"DeviceName\":\"/dev/sda1\",\"Ebs\":{ \
      \"VolumeSize\":30, \
      \"DeleteOnTermination\":true}}]" \
    --query 'Instances[*].InstanceId' \
    --output text)
  aws ec2 wait instance-running --instance-ids "$ec2_id" &
  activity_show
  cmd_check

  aced_cfg_push ec2_id

  echo -e "\n$green \bAdding name tag: $ec2_tag to $ec2_id..."
  aws ec2 create-tags \
    --resources "$ec2_id" \
    --tags Key=Name,Value="$ec2_tag"
  cmd_check

  echo -e "\n$yellow \bReview EC2 instances in AWS web console:"
  echo -e "\n$gray \b$aws_con#Instances"
} # end func: ec2_launch

ec2_reboot() {
  ec2_state
  [[ "$state" != "Running" ]] && { echo -e "\n$state_msg"; return; }

  echo -e "\n$green \bRemote: rebooting EC2 instance: $ec2_tag... "
  aws ec2 reboot-instances --instance-ids "$ec2_id"
  aws ec2 wait instance-running --instance-ids "$ec2_id" &
  activity_show
  cmd_check

  echo -e "\n$green \bRemote: waiting on SSH port to accept connections... "
  ec2_eip_fetch silent # fetch current EIP
  aws_waiter SSH silent &
  activity_show

  [[ "$1" == "menu" ]] \
    && read -n 1 -s -p "$yellow""Press any key to continue "; clear
}

ec2_rebuild() {
  ###################################################################
  ####  Rebuild ACED: new EC2 instance, old EIP & old web certs  ####
  ###################################################################
  ec2_eip_fetch silent

  echo -e "\n$green \bFetching ACED's EIP association ID..."
  eip_assoc_id=$(aws ec2 describe-addresses \
    --filters Name=public-ip,Values=$ec2_ip_last \
    --query Addresses[*].AssociationId \
    --output text)
  cmd_check

  echo -e "\n$green \bDisassociating EIP from EC2 instance: $ec2_tag..."
  aws ec2 disassociate-address --association-id $eip_assoc_id
  cmd_check

  ec2_terminate $ec2_id redo  # invoke func: remove ACED instance
  ec2_launch redo             # invoke func: create ACED instance

  echo -e "\n$green \bAssociating EIP with EC2 instance: $ec2_tag... \n$reset"
  aws ec2 associate-address \
    --allocation-id $eip_id \
    --instance-id $ec2_id \
    --output table
  cmd_check

  os_sec                      # invoke func: create user/push key/harden
  os_app                      # invoke func: update/install/config apps
  os_misc                     # invoke func: one-off tasks
  ec2_reboot                  # invoke func: cross fingers
  cert_get redo               # invoke func: copy web certs/update nginx config
}

ec2_start(){
  ec2_state
  [[ "$state" != "Stopped" ]] && { echo -e "\n$state_msg"; return; }

  echo -e "\n$green \bStarting $aced_nm... \n$blue"
  aws ec2 start-instances --instance-ids "$ec2_id"
  aws ec2 wait instance-running --instance-ids "$ec2_id" &
  activity_show
  cmd_check

  ec2_eip_create rotate     # allocate & associate new EIP
  ec2_eip_fetch last        # fetch old and new EIP address
  ssh_alias_create update   # update ssh connection alias with new IP
  known_host_add update     # update EC2 host in known_host
  aced_cfg_push ec2_ip      # push updated IP to config

  [[ "$1" == "menu" ]] \
    && read -n 1 -s -p "$yellow""Press any key to continue "; clear
}

ec2_stop() {
  ec2_state
  [[ "$state" != "Running" ]] && { echo -e "\n$state_msg"; return; }

  notify eip_gist
  decision_response Continue stopping $aced_nm?

  if [[ "$response" =~ [yY] ]]; then
    ec2_eip_remove  # invoke func: disassociate & release EIP

    echo -e "$green\nStopping $aced_nm... \n$blue"
    aws ec2 stop-instances --instance-ids "$ec2_id"
    aws ec2 wait instance-stopped --instance-ids "$ec2_id" &
    activity_show
    cmd_check

    [[ "$1" == "menu" ]] \
      && read -n 1 -s -p "$yellow""Press any key to continue "; clear
  fi
}

ec2_terminate() {
  argument_check
  if [ "$2" != "redo" ]; then
    ec2_eip_remove $1 # invoke func: check existing/remove EIP; pass $ec2_id
  fi
  echo -e "\n$green \bTerminating instance ID: $1... \n$blue"
  aws ec2 terminate-instances --instance-ids "$1"
  aws ec2 wait instance-terminated --instance-ids "$1" &
  activity_show
  cmd_check
}

ec2_key_fp_check() {
  # console log takes too long to populate for use during EC2 launch
  # console log only holds last 64k of data
  # check EC2 public key fingerprint; match to localhost's fingerprint
  echo -e "\n$white \b*** EC2 Public Key Fingerprint Check ***"

  echo -e "\n$green \bFetching localhost public key fingerprint..."
  key_fp=$(ssh-keygen -l -E md5 -f $aced_keys/$ssh_key_public \
  | awk '{gsub("MD5:",""); print $2}')
  cmd_check

  echo -e "\n$green \bFetching EC2 public key fingerprint..."
  ec2_key_fp=$(aws ec2 get-console-output \
    --instance-id $ec2_id \
    --output text \
    | grep -o "$key_fp")
  cmd_check

  if [ "$key_fp" == "$ec2_key_fp" ]; then
    echo -e "\n$yellow \bPublic key fingerprints match! $reset"
  else
    echo -e "\n$red \bPublic fingerprints don't match! $reset"
    exit 1
  fi
}
