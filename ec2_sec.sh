#!/usr/bin/env bash

#####################################################
##  filename:   ec2_sec.sh                         ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    EC2 security tasks                 ##
##  date:       03/18/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

ec2_sec() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Security Key Pairs/Group/Rules  XX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  ec2_sec_keypair           # check/create/key pair/import EC2 public key
  ec2_sec_group             # check/create EC2 security group
  ec2_sec_rule_ingress_add  # check/authorize inbound security rules
  ec2_sec_rule_egress_add   # authorize outbound security rules
}
ec2_connect() {
  ec2_sec_rule_ingress_add  # invoke function to check IP/add new ingress rule
  ssh $ssh_alias            # use SSH connection alias to connect to instance
}

ec2_sec_rule_list() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  List all EC2 security group rules  XXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bFetching EC2 security group IDs..."
  group_ids=($(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].[GroupId]' \
    --output text)
    )
  return_check

  echo -e "\n$green \bChecking EC2 security group rules..."
  if [ "${#group_ids[@]}" -gt 0 ]; then
    for g in "${group_ids[@]}"; do
      name=$(aws ec2 describe-security-groups \
        --group-ids $g \
        --query 'SecurityGroups[*].[GroupName]' \
        --output text)

      inbound=$(aws ec2 describe-security-groups \
        --group-ids $g \
        --query 'SecurityGroups[*].IpPermissions[]' \
        | awk '/FromPort/ || /CidrIp/ { \
          gsub(/\"/,""); \
          gsub(/\[/,""); \
          gsub(/,/,""); \
          print $1,"\t"$2}')

      outbound=$(aws ec2 describe-security-groups \
        --group-ids $g \
        --query 'SecurityGroups[*].IpPermissionsEgress[]' \
        | awk '/FromPort/ || /CidrIp/ { \
          gsub(/\"/,""); \
          gsub(/\[/,""); \
          gsub(/,/,""); \
          print $1, "\t"$2}')

      echo -e "$blue\n \b####################################"
      echo -e "$blue \bGroup Name: \t$name: \nGroup ID: \t$g \
      \n\nInbound Rules (localhost => EC2):"

      if [ -z "$inbound" ]; then
        echo -e "$blue \bNone!"
      else
        echo -e "$blue \b$inbound"
      fi

      echo -e "\n$blue \bOutbound Rules (EC2 => localhost):"
      if [ -z "$outbound" ]; then
        echo -e "$blue \bNone!"
      else
        echo -e "$blue \b$outbound"
      fi
    done
  else
    echo -e "\n$blue \bNo EC2 Security Groups Found"
  fi
}

ec2_sec_keypair() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Localhost/EC2: Key Pair Creation  XXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bChecking for existing localhost ACED key..."

  if [ -f $aced_keys/$ssh_key_private ]; then
    echo -e "\n$green \bDeleting localhost ACED key pair: $ssh_key_private..."
    rm -f $aced_keys/$ssh_key_private* &>/dev/null
    return_check
    echo -e "\n$green \bRemoving ACED private key from localhost SSH agent..."
    ssh-add -d "$ssh_key_private"
    return_check
  else
    echo -e "\n$yellow \bNo localhost ACED key pair found!"
  fi

  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Key Pair Check  XXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bChecking for existing EC2 key pairs..."
  key_pairs=($(aws ec2 describe-key-pairs \
    --query KeyPairs[*].KeyName \
    --output text)
    )

  if [ ${#key_pairs[@]} -gt 0 ]; then
    for k in "${key_pairs[@]}"; do
      echo -e "\n$blue \bEC2 key pair found: $k \n$yellow"

      if [ $k == "$ssh_key_public" ]; then
        key_rm=true
      else
        read -rp "Remove EC2 key pair: $k? [Y/N] " response
        if [[ "$response" =~ ^([nN][oO]|[nN])+$ ]]; then
          key_rm=false
        fi
      fi
      if [ "$key_rm" != false  ]; then
        echo -e "\n$green \bDeleting EC2 key pair: $k..."
        aws ec2 delete-key-pair --key-name "$k" \
        return_check
      else
        echo -e "\n$yellow \bKeeping EC2 key pair!"
      fi
    done
  else
    echo -e "\n$blue \bNo EC2 key pairs found!"
  fi

  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXXXX  Localhost: Key Pair Creation  XXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$yellow \bCreate a new passphrase for your key pair... \
  \n\nStore it in a secure location, e.g. password manager app!"

  echo -e "\n$green \bCreating localhost key pair: $ssh_key_private...\n$blue"
  ssh-keygen -t rsa -b 4096 -f $aced_keys/$ssh_key_private -C $ssh_key_private
  return_check

  echo -e "\n$green \bSetting file permissions on private key = 400"
  chmod =,u+r $aced_keys/$ssh_key_private
  return_check

  echo -e "\n$green \bSetting file permissions on public key = 644"
  chmod =,u+rw,go=r $aced_keys/$ssh_key_public
  return_check

  echo -e "\n$green \bCreating symlink to private key... \n$blue"
  ln -sf $aced_keys/$ssh_key_private ~/.ssh
  return_check

  echo -e "\n$green \bAdding private key to SSH agent... \n$blue"
  /usr/bin/ssh-add -K $aced_keys/$ssh_key_private
  return_check

  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Key Pair Import (public key) XXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bImporting localhost public key to EC2... \n$blue"
  aws ec2 import-key-pair \
  --key-name $ssh_key_public \
  --public-key-material file://$aced_keys/$ssh_key_public
  return_check
}

ec2_sec_group() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Security Group Creation  XXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bChecking for existing EC2 groups..."
  ec2_groups=($(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].{Name:GroupName}' \
    --output text \
    | grep -v "default")
    )

  if [ ${#ec2_groups[@]} -gt 0 ]; then
    for g in "${ec2_groups[@]}"; do
      echo -e "\n$blue \bEC2 group found: $g \n$yellow"

      if [ $g == "$ec2_group" ]; then
        group_rm=true
      else
        read -rp "Remove EC2 group $g? [Y/N] " response
        if [[ "$response" =~ ^([nN][oO]|[nN])+$ ]]; then
          group_rm=false
        fi
      fi

      if [ "$group_rm" != false  ]; then
        echo -e "\n$green \bDeleting EC2 group: $g..."
        aws ec2 delete-security-group --group-name "$g"
        return_check
      else
        echo -e "\n$yellow \bKeeping EC2 group: $g!"
      fi
    done
  else
    echo -e "\n$blue \bNo EC2 group found!"
  fi

  echo -e "\n$green \bFetching VPC ID... \n$blue"
  ec2_vpc_id=$(aws ec2 describe-vpcs --query Vpcs[].VpcId --output text)
  echo -e "\n$blue \bVPC ID: $ec2_vpc_id \n"
  update_config ec2_vpc_id

  echo -e "\n$green \bCreating EC2 group: $ec2_group... \n$blue"
  ec2_group_id=$(aws ec2 create-security-group \
    --group-name $ec2_group \
    --description "$ec2_group_desc" \
    --vpc-id $ec2_vpc_id \
    --output text)
  return_check
  update_config ec2_group_id
}

ec2_sec_rule_ingress_add(){
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Authorize Ingress Rule (SSH)  XXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  new_public_ip=$(curl -s http://checkip.amazonaws.com)

  if [ $new_public_ip != "public_ip"  ]; then
    echo -e "\n$yellow \bYou have a new public IP address!"

    echo -e "\n$green \bApplying 32-bit netmask in CIDR format... \n"
    new_public_ip=$new_public_ip/32

    echo -e "\n$green \bAdding inbound rule for SSH access: \
    \nTo: $ec2_title from: $new_public_ip \n$blue"
    aws ec2 authorize-security-group-ingress \
    --group-id $ec2_group_id \
    --protocol tcp \
    --port 22 \
    --cidr $new_public_ip
    return_check

    echo -e "\n$green \bRevoking inbound rule for SSH access: \
    \nTo: $ec2_title from: $public_ip/32 \n$blue"
    aws ec2 revoke-security-group-ingress \
      --group-id $ec2_group_id \
      --protocol tcp \
      --port 22 \
      --cidr $public_ip
    return_check

    public_ip=$new_public_ip
    update_config public_ip
  fi
}

ec2_sec_rule_egress_add(){
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  EC2: Authorize Egress Rules (HTTP/S)  XXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bAdding outbound rule for HTTP traffic: \
  \nFrom: $ec2_title to: 0.0.0.0/0 (anywhere) \n$blue"
  aws ec2 authorize-security-group-egress \
    --group-id $ec2_group_id \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0
  return_check

  echo -e "$green\nAdding outbound rule for HTTPS traffic: \
  \nFrom: $ec2_title to: 0.0.0.0/0 (anywhere) \n$blue"
  aws ec2 authorize-security-group-egress \
    --group-id $ec2_group_id \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0
  return_check
}
