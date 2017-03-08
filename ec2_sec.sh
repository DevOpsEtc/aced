#!/usr/bin/env bash

####################################################
##  filename:   ec2_sec.sh                        ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    EC2 security tasks                ##
##  date:       03/04/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

aed_ec2_sec() {
  aed_ec2_sec_keypair
  aed_ec2_sec_group
  aed_ec2_sec_rules
}

aed_ec2_rotate_keys() {
  aed_ec2_sec_keypair
}

aed_ec2_sec_keypair() {
  echo -e "$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Check Localhost Key Pair  XXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with localhost key-pair names
  aed_get_kp_local=($(ls "$aed_keys"))

  # populate array with localhost private key names
  aed_get_prv_local=($(ls | grep -v  "\."))

  # list any localhost key pairs & prompt to delete
  if [ ${#aed_get_kp_local[@]} -ne 0 ]; then
    echo -e "\n$aed_ylw \bFound localhost key pair(s): "
    echo $aed_blu; printf '%s\n' "${aed_get_kp_local[@]}"
    echo $aed_ylw; read -rp "Delete all localhost key pair(s)? [Y/N] " aed_opt
    echo

    if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      for k in "${aed_get_kp_local[@]}"; do
        echo -e "\n$aed_grn \bDeleting localhost key pair: $k..."
        rm -f "$k" && echo -e "\n$aed_blu $aed_ok_icon" || return
      done

      for p in "${aed_get_prv_local[@]}"; do
        echo -e "\n$aed_grn \bRemoving private key from SSH agent: $k..."
        ssh-add -d "$p" && echo -e "\n$aed_blu $aed_ok_icon" || return
      done

      unset aed_get_kp_local aed_get_prv_local
    else
      echo -e "\n$aed_ylw \bKeeping localhost key pair(s)!"
    fi
    echo -e "\n$aed_blu \bNo localhost key pair found!"
  fi

  echo -e "$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Check Existing EC2 Key Pair  XXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with key-pair names
  aed_get_key_pair=($(aws ec2 describe-key-pairs \
    --query KeyPairs[*].KeyName \
    --output text)
  )

  # list any key pairs & prompt to delete
  if [ ${#aed_get_key_pair[@]} -ne 0 ]; then
    echo -e "\n$aed_ylw \bFound EC2 key pair(s): "
    echo $aed_blu; printf '%s\n' "${aed_get_key_pair[@]}"
    echo $aed_ylw; read -rp "Delete all EC2 key pair(s)? [Y/N] " aed_opt
    echo

    if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      for k in "${aed_get_key_pair[@]}"; do
        echo -e "\n$aed_grn \bDeleting EC2 key pair: $k..."
        aws ec2 delete-key-pair --key-name "$k" \
        && echo -e "\n$aed_blu $aed_ok_icon" || return
      done
      unset aed_get_key_pair
    else
      echo -e "\n$aed_ylw \bKeeping key pair(s)!"
    fi
    echo -e "\n$aed_blu \bNo EC2 key pair found!"
  fi

  echo -e "$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Create New Localhost Key Pair  XXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  unset aed_ec2_key_name aed_ec2_key # delete key pair var

  while [ "$aed_ec2_key_name" != "valid" ] ; do
    echo $aed_ylw
    read -rp "Enter name for new key pair, e.g. name_keypair: " \
      aed_ec2_key

    # name for public key; append ".pub" to value
    aed_ec2_key_pub=$aed_ec2_key.pub

    # does the EC2 key pair exist
    if echo "${aed_get_key_pair[@]}" | grep -q -w "$aed_ec2_key.pub"; then
      echo -e "\n$aed_red \bEC2 key pair already exists: $aed_ec2_key"
    else
      aed_ec2_key_name=valid
    fi
  done

  echo -e "\n$aed_ylw \bYou will now be prompted to enter a passphrase twice. \
  \b\bStore passphrase in a secure location!"

  echo -e "\n$aed_grn \bCreating key pair: $aed_ec2_key... \n$aed_blu"
  ssh-keygen -t rsa -b 4096 -f $aed_keys/$aed_ec2_key -C "$aed_ec2_key" \
  && echo -e "\n$aed_blu $aed_ok_icon" || return

  echo -e "\n$aed_grn \bSetting file permissions on keypair: \
  \b\b$aed_ec2_key... \n$aed_blu"
  chmod =,u+r $aed_keys/$aed_key_name \
    && chmod =,u+rw $aed_keys/$aed_key_name_pub \
    && echo -e "\n$aed_blu $aed_ok_icon" || return

  echo -e "\n$aed_grn \bCreating symlink to private key... \n$aed_blu"
  ln -sf $aed_keys/$aed_ec2_key $aed_ssh_dotfile \
    && echo -e "\n$aed_blu $aed_ok_icon" || return

  echo -e "\n$aed_grn \bAdding private key to SSH agent... \n$aed_blu"
  /usr/bin/ssh-add -K $aed_keys/$aed_ec2_key \
    && echo -e "\n$aed_blu $aed_ok_icon" || return

  echo -e "$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Import Localhost Key Pair to EC2  XXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$aed_grn \bImporting public key... \n$aed_rst"
  aws ec2 import-key-pair \
  --key-name $aed_key_name_pub \
  --public-key-material file://$aed_keys/$aed_key_name_pub \
  && echo -e "\n$aed_blu $aed_ok_icon" || return

  # invoke function to update placeholder values of passed args in AED config
  aed_update_config aed_ec2_key aed_ec2_key_pub
}

aed_ec2_sec_group() {
  echo -e "$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Check EC2 Security Group  XXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with EC2 security group names (ignore default)
  aed_get_ec2_group=($(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].{Name:GroupName}' \
    --output text \
    | grep -v "default")
  )

    if [ ${#aed_get_ec2_group[@]} -ne 0 ]; then
      echo -e "\n$aed_ylw \bFound EC2 security group(s): "
      echo $aed_blu; printf '%s\n' "${aed_get_ec2_group[@]} $aed_ylw"
      read -rp "Delete all EC2 security group(s)? [Y/N] " aed_opt
      echo

      if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        # loop through list of EC2 group names
        for g in "${aed_get_ec2_group[@]}"; do
          echo -e "\n$aed_grn \bDeleting security group..."
          aws ec2 delete-security-group --group-name "$g" \
          && echo -e "\n$aed_blu $aed_ok_icon" || return
        done

        unset aed_get_ec2_group
      else
        echo -e "\n$aed_grn \bKeeping EC2 security group(s)!"
      fi
    else
      echo -e "\n$aed_ylw \bNo EC2 security group found!"
    fi

  echo -e "$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Create EC2 Security Group  XXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  unset aed_ec2_group_name aed_ec2_group aed_sec_group_desc # delete group vars

  while [ "$aed_ec2_group_name" != "valid" ] ; do
    echo $aed_ylw
    read -rp "Enter name for new EC2 security group, e.g. name_group: " \
      aed_ec2_group

    # check for existing EC2 group name
    if echo "${aed_get_ec2_group[@]}" | grep -q -w "$aed_ec2_group"; then
      echo -e "\n$aed_red \bEC2 security group already exists: $aed_ec2_group"
    else
      aed_ec2_group_name=valid
    fi
  done

  echo $aed_ylw
  read -rp 'Enter security group description, e.g. Blog security group: ' \
    aed_sec_group_desc

  echo -e "\n$aed_grn \bCreating $aed_ec2_group..."
  echo $aed_blu; aws ec2 create-security-group \
    --group-name $aed_ec2_group \
    --description "$aed_sec_group_desc" \
    && echo -e "\n$aed_blu $aed_ok_icon" || return

  # invoke function to update placeholder values of passed args in AED config
  aed_update_config aed_ec2_group
}

aed_ec2_sec_rules() {
  echo -e "$aed_wht
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Check EC2 Security Group Rules  XXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with security group rule names; ignore default
  aed_get_group_rule=($(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].{Name:IpPermissions}' \
    --output text \
    | grep -v "default")
  )

# add /32
# revoke /32:
# clear entry
# aed_temp_access_ip

# anywhere (0.0.0.0/0, ::/0)
# my ISP (netmask 24)
# my IP (netmask 32)




  # check for security group rules; do if found
  echo -e "\n$aed_grn \bChecking existing EC2 security group rules... $aed_rst"
  if $(aws ec2 describe-security-groups \
    --output text \
    --query 'SecurityGroups[*].{Name:GroupName}' \
    | grep -v "default"); then

    echo -e "\n$aed_blu \bEC2 security group rule found: \n $aed_rst"
    aws ec2 describe-key-pairs --output table
  fi




  # add EC2 security group ingress rule
  aws ec2 authorize-security-group-ingress --group-name $aed_sec_group \
    --protocol tcp --port $aed_sec_rule_port --cidr $aed_ip_cidr



  # prompt for custom ssh access port
  read -rp $'\n\nEnter custom port for remote access, e.g. 1337: ' \
    aed_sec_rule_port

# separate function for -secRule
    # cidr vs. my IP
  # prompt for cidr format
  read -rp $'\n\nEnter ISP IP, e.g. 1337: ' aed_ip_cidr


  # create security group rules
  # add rule allowing inbound traffic on custom TCP port
  # public IP address in CIDR notation http://checkip.amazonaws.com
  # narrow to subnet
  # temp access via unknown ISP: add new rule @web console:
  # custom rule: tcp: port: : myIP
  $ aws ec2 authorize-security-group-ingress --group-name $aed_sec_group \
    --protocol tcp --port $aed_sec_rule_port --cidr $aed_ip_cidr
    # 50.170.168.0/24

  # view security group rules
  $ aws ec2 describe-security-groups --group-name $aed_sec_group

  # remove security group rule
  $ aws ec2 revoke-security-group-ingress \
    --group-name $aed_sec_group \
    --protocol tcp \
    --port $aed_sec_rule_port \
    --cidr $aed_ip_cidr
}
