#!/usr/bin/env bash

#####################################################
##  filename:   ec2_sec.sh                         ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    EC2 security tasks                 ##
##  date:       03/16/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

ec2_sec() {
  ec2_sec_keypair
  ec2_sec_group
  ec2_sec_rules
}

ec2_keypair_rotate() {
  ec2_sec_keypair
}

ec2_rule_add(){
  :
}

ec2_sec_keypair() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Localhost: Key Pair Creation  XXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with localhost key-pair names
  get_kp_local=($(ls "$aced_keys"))

  # populate array with localhost private key names
  get_prv_local=($(ls | grep -v  "\."))

  # list any localhost key pairs & prompt to delete
  if [ ${#get_kp_local[@]} -ne 0 ]; then
    echo -e "\n$yellow \bFound localhost key pair(s): "
    echo $blue; printf '%s\n' "${get_kp_local[@]}"
    echo $yellow; read -rp "Delete all localhost key pair(s)? [Y/N] " response
    echo

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      for k in "${get_kp_local[@]}"; do
        echo -e "\n$green \bDeleting localhost key pair: $k..."
        rm -f "$k"
        return_check
      done

      for p in "${get_prv_local[@]}"; do
        echo -e "\n$green \bRemoving private key from SSH agent: $k..."
        ssh-add -d "$p"
        return_check
      done

      unset get_kp_local get_prv_local
    else
      echo -e "\n$yellow \bKeeping localhost key pair(s)!"
    fi
    echo -e "\n$blue \bNo localhost key pair found!"
  fi

  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Check Existing EC2 Key Pair  XXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with key-pair names
  get_key_pair=($(aws ec2 describe-key-pairs \
    --query KeyPairs[*].KeyName \
    --output text)
  )

  # list any key pairs & prompt to delete
  if [ ${#get_key_pair[@]} -ne 0 ]; then
    echo -e "\n$yellow \bFound EC2 key pair(s): "
    echo $blue; printf '%s\n' "${get_key_pair[@]}"
    echo $yellow; read -rp "Delete all EC2 key pair(s)? [Y/N] " response
    echo

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      for k in "${get_key_pair[@]}"; do
        echo -e "\n$green \bDeleting EC2 key pair: $k..."
        aws ec2 delete-key-pair --key-name "$k" \
        return_check
      done
      unset get_key_pair
    else
      echo -e "\n$yellow \bKeeping key pair(s)!"
    fi
    echo -e "\n$blue \bNo EC2 key pair found!"
  fi

  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Create New Localhost Key Pair  XXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$yellow \bYou will now be prompted to enter a passphrase twice. \
  \b\bStore passphrase in a secure location!"

  echo -e "\n$green \bCreating key pair: $ssh_key_private... \n$blue"
  ssh-keygen -t rsa -b 4096 -f $aced_keys/$ssh_key_private -C "$ssh_key_private"
  return_check

  echo -e "\n$green \bSetting file permissions on $ssh_key_private \
  \b\b($ssh_key_private: 400 & $ssh_key_public: 644) ... \n$blue"
  chmod =,u+r $aced_keys/$ssh_key_private && chmod =,u+rw,go=r $aced_keys/$ssh_key_public
  return_check

  echo -e "\n$green \bCreating symlink to private key... \n$blue"
  ln -sf $aced_keys/$ssh_key_private $ssh_config
  return_check

  echo -e "\n$green \bAdding private key to SSH agent... \n$blue"
  /usr/bin/ssh-add -K $aced_keys/$ssh_key_private
  return_check

  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Import Localhost Key Pair to EC2  XXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bImporting public key... \n$reset"
  aws ec2 import-key-pair \
  --key-name $ssh_key_public \
  --public-key-material file://$aced_keys/$ssh_key_public
  return_check
}

ec2_sec_group() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Security Group Creation  XXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with EC2 security group names (ignore default)
  get_ec2_group=($(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].{Name:GroupName}' \
    --output text \
    | grep -v "default")
    )

  if [ ${#get_ec2_group[@]} -ne 0 ]; then
    echo -e "\n$yellow \bFound EC2 security group(s): "
    echo $blue; printf '%s\n' "${get_ec2_group[@]} $yellow"
    read -rp "Delete all EC2 security group(s)? [Y/N] " response
    echo

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      # loop through list of EC2 group names
      for g in "${get_ec2_group[@]}"; do
        echo -e "\n$green \bDeleting security group..."
        aws ec2 delete-security-group --group-name "$g"
        return_check
      done
    else
      echo -e "\n$green \bKeeping EC2 security group(s)!"
    fi
  else
    echo -e "\n$yellow \bNo EC2 security group found!"
  fi

  echo -e "\n$green \bCreating $ec2_group..."
  echo $blue; aws ec2 create-security-group \
    --group-name $ec2_group \
    --description "$ec2_group_desc"
  return_check
}

ec2_sec_rules() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Check EC2 Security Group Rules  XXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with security group rule names; ignore default
  get_group_rule=($(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].{Name:IpPermissions}' \
    --output text \
    | grep -v "default")
  )

# add /32
# revoke /32:
# clear entry
# temp_access_ip

  # check for security group rules; do if found
  echo -e "\n$green \bChecking existing EC2 security group rules... $reset"
  if $(aws ec2 describe-security-groups \
    --output text \
    --query 'SecurityGroups[*].{Name:GroupName}' \
    | grep -v "default"); then

    echo -e "\n$blue \bEC2 security group rule found: \n $reset"
    aws ec2 describe-key-pairs --output table
  fi

  # add EC2 security group ingress rule
  aws ec2 authorize-security-group-ingress --group-name $ec2_group \
    --protocol tcp --port $ec2_ssh_port --cidr $ec2_access_ip_hm


  # create security group rules
  # add rule allowing inbound traffic on custom TCP port
  # public IP address in CIDR notation http://checkip.amazonaws.com
  # narrow to subnet
  # temp access via unknown ISP: add new rule @web console:
  # custom rule: tcp: port: : myIP
  $ aws ec2 authorize-security-group-ingress --group-name $ec2_group \
    --protocol tcp --port $ec2_ssh_port --cidr $ec2_access_ip
    # 50.170.168.0/24

  # view security group rules
  $ aws ec2 describe-security-groups --group-name $ec2_group

  # remove security group rule
  $ aws ec2 revoke-security-group-ingress \
    --group-name $ec2_group \
    --protocol tcp \
    --port $ec2_ssh_port \
    --cidr $ec2_access_ip
}
