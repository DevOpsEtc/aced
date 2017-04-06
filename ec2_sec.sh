#!/usr/bin/env bash

#####################################################
##  filename:   ec2_sec.sh                         ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    EC2 security tasks                 ##
##  date:       04/06/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

ec2_sec() {
  echo -e "$white
  \b\b#########################################
  \b\b##  EC2: Security Key Pair/Group/Rule  ##
  \b\b#########################################"

  ec2_keypair           # check/create/key pair/import EC2 public key
  ec2_group_create      # check/create EC2 security group
  ec2_rule_ingress_add  # check/authorize inbound security rules
  ec2_rule_egress_add   # authorize outbound security rules
  ec2_rule_revoke all   # revoke default inbound/outbound rules
}

ec2_rule_list() {
  echo -e "\n$green \bFetching EC2 security group IDs..."
  group_ids=($(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].[GroupId]' \
    --output text)
  )
  exit_code_check

  echo -e "\n$green \bFetching EC2 security group rules..."
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

      echo -e "$gray\n \b#################################### \
        \nGroup Name: \t$blue$name$gray: \nGroup ID: \t$blue$g$gray \
        \n\nInbound Rules (localhost => EC2):"

      if [ -z "$inbound" ]; then
        echo -e "$blue \bNone!"
      else
        echo -e "$blue \b$inbound"
      fi

      echo -e "\n$gray \bOutbound Rules (EC2 => localhost):"
      if [ -z "$outbound" ]; then
        echo -e "$blue \bNone!"
      else
        echo -e "$blue \b$outbound"
      fi
    done
  else
    echo -e "\n$blue \bNo EC2 Security Groups Found"
  fi
  read -n 1 -s -p $'\n'"$yellow""Press any key to continue "
  clear && clear
}

ec2_keypair() {
  echo -e "\n$white \b****  Localhost/EC2: Key Pair Creation  ****"

  echo -e "\n$green \bChecking for existing EC2 key pairs..."
  key_pairs=($(aws ec2 describe-key-pairs \
    --query KeyPairs[*].KeyName \
    --output text)
  )
  exit_code_check

  if [ ${#key_pairs[@]} -gt 0 ]; then
    for k in "${key_pairs[@]}"; do
      echo -e "\n$blue \bEC2 key pair found: $k"
      if [ $k == "$ssh_key_public" ]; then
        key_rm=true
      else
        decision_response Remove EC2 key pair: $k?
        [[ "$response" =~ [nN] ]] && key_rm=false
      fi

      if [ "$key_rm" != false  ]; then
        echo -e "\n$green \bDeleting EC2 key pair: $k..."
        aws ec2 delete-key-pair --key-name "$k"
        exit_code_check
      else
        echo -e "\n$yellow \bKeeping EC2 key pair!"
      fi
    done
  else
    echo -e "\n$blue \bNo EC2 key pairs found!"
  fi

  echo -e "\n$green \bChecking localhost SSH Agent for $ssh_key_private..."
  if ssh-add -L | grep -q "$aced_keys/$ssh_key_private"; then
    echo -e "\n$green \bRemoving $ssh_key_private from SSH Agent..."
    ssh-add -d $aced_keys/$ssh_key_private &>/dev/null
    exit_code_check
  else
    echo -e "\n$blue \bNo SSH Agent entry for $ssh_key_private found!"
  fi

  echo -e "\n$green \bChecking for localhost keypair: $aced_nm... "
  if [ -f $aced_keys/$ssh_key_private ]; then
    echo -e "\n$blue \bFound localhost key pair: $aced_nm!"
    echo -e "\n$green \bDeleting localhost key pair: $aced_nm... "
    rm -f $aced_keys/$ssh_key_private* &>/dev/null
    exit_code_check
  else
    echo -e "\n$blue \bNo localhost key pair $aced_nm found!"
  fi

  echo -e "\n$white \b****  Localhost: Key Pair Creation  ****"

  echo -e "\n$yellow \bCreate a passphrase for your new key pair: \
  \n\n- Store in secure location, e.g. password manager app! \
  \n- Do not use an empty passphrase! \
  \n- Passphrase must be minimum of five characters!"

  echo -e "\n$green \bCreating localhost key pair: $ssh_key_private...\n$blue"
  ssh-keygen -t rsa -b 4096 -f $aced_keys/$ssh_key_private -C $ssh_key_private
  exit_code_check

  echo -e "\n$green \bSetting file permissions on key pair = 400"
  chmod u=r,go-rwx $aced_keys/*
  exit_code_check

  echo -e "\n$green \bSetting file permissions on public key = 644"
  chmod u=rw,go=r $aced_keys/$ssh_key_public
  exit_code_check

  echo -e "\n$green \bAdding private key to SSH agent... \n$blue"
  /usr/bin/ssh-add -K $aced_keys/$ssh_key_private
  exit_code_check

  echo -e "\n$white \b****  EC2: Key Pair Import (public key)  ****"

  echo -e "\n$green \bImporting localhost public key to EC2... \n$blue"
  aws ec2 import-key-pair \
  --key-name $ssh_key_public \
  --public-key-material file://$aced_keys/$ssh_key_public
  exit_code_check
}

ec2_group_remove() {
  echo -e "\n$green \bChecking for existing EC2 groups..."
  ec2_groups=($(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].{Name:GroupName}' \
    --output text \
    | grep -v "default")
  )
  exit_code_check

  if [ ${#ec2_groups[@]} -gt 0 ]; then
    for g in "${ec2_groups[@]}"; do
      echo -e "\n$blue \bEC2 group found: $g"

      if [ $g == "$ec2_group" ]; then
        group_rm=true
      else
        decision_response Remove EC2 group: $g?
        [[ "$response" =~ [nN] ]] && group_rm=false
      fi

      if [ "$group_rm" != false  ]; then
        echo -e "\n$green \bChecking for network interfaces..."
        net_interface_status=$(aws ec2 describe-network-interfaces \
          --filters Name=group-name,Values=$g \
          --query 'NetworkInterfaces[*].Status' \
          --output text)
        exit_code_check

        if [ "$net_interface_status" == "in-use" ]; then
          echo -e "\n$blue \bNetwork interface found!"

          echo -e "\n$green \bFetching instance ID..."
          instance_id=$(aws ec2 describe-network-interfaces \
            --filters Name=group-name,Values=$g \
            --query 'NetworkInterfaces[*].Attachment[].InstanceId' \
            --output text)
          exit_code_check

          echo -e "\n$yellow \bCan't remove $g while associated with instance \
          \b\b\b\b\b\b\b\b\b\bID: $instance_id"

          ec2_warn_multiple # invoke function to display warning

          decision_response Terminate instance: $instance_id?
          [[ "$response" =~ [yY] ]] && ec2_terminate $instance_id || return
        else
          echo -e "\n$blue \bNo network interface found!"
        fi

        echo -e "\n$green \bDeleting EC2 group: $g..."
        aws ec2 delete-security-group --group-name "$g"
        exit_code_check
      else
        echo -e "\n$yellow \bKeeping EC2 group: $g!"
      fi
    done
  else
    echo -e "\n$blue \bNo EC2 group found!"
  fi
}

ec2_group_create() {
  echo -e "\n$white \b****  EC2: Security Group Creation  ****"

  ec2_group_remove

  echo -e "\n$green \bFetching VPC ID... $blue"
  ec2_vpc_id=$(aws ec2 describe-vpcs \
    --query Vpcs[*].VpcId \
    --output text)
  exit_code_check

  aced_config_update ec2_vpc_id

  echo -e "\n$green \bCreating EC2 group: $ec2_group... $blue"
  ec2_group_id=$(aws ec2 create-security-group \
    --group-name $ec2_group \
    --description "$ec2_group_desc" \
    --vpc-id $ec2_vpc_id \
    --output text)
  exit_code_check

  aced_config_update ec2_group_id
}

ec2_rule_revoke() {
  argument_check
  if [ "$1" == "inbound_22" ]; then
    echo -e "\n$green \bRevoking inbound rule (localhost => EC2): \
    \n\n$blue \bPort: 22 \
    \nFrom: $localhost_ip \
    \nTo: EC2 Instance: $ec2_tag"
    aws ec2 revoke-security-group-ingress \
      --group-id $ec2_group_id \
      --protocol tcp \
      --port 22 \
      --cidr $localhost_ip
    exit_code_check
  elif [ "$1" == "inbound_$ec2_ssh_port" ]; then
    echo -e "\n$green \bRevoking inbound rule (localhost => EC2): \
    \n\n$blue \bPort: $ec2_ssh_port \
    \nFrom: $localhost_ip \
    \nTo: EC2 Instance: $ec2_tag"
    aws ec2 revoke-security-group-ingress \
      --group-id $ec2_group_id \
      --protocol tcp \
      --port $ec2_ssh_port \
      --cidr $localhost_ip
    exit_code_check
  elif [ "$1" == "all" ]; then
    echo -e "\n$green \bFetching default security group ID..."
    group_id_def=$(aws ec2 describe-security-groups \
      --filters 'Name=group-name,Values=default' \
      --query 'SecurityGroups[*].GroupId' \
      --output text)
    exit_code_check

    echo -e "\n$green \bRevoking inbound \"All\" rule on group ID: \
      \n$group_id_def (localhost => EC2)"
    aws ec2 revoke-security-group-ingress \
      --group-id $group_id_def \
      --protocol -1 \
      --port all \
      --cidr 0.0.0.0/0
    exit_code_check

    echo -e "\n$green \bFetching all EC2 security group IDs..."
    sec_groups=($(aws ec2 describe-security-groups \
      --query 'SecurityGroups[*].GroupId' \
      --output text)
    )
    exit_code_check

    if [ "${#sec_groups[@]}" -gt 0 ]; then
      for i in "${sec_groups[@]}"; do
        echo -e "\n$green \bRevoking outbound \"All\" rule on group ID: \
          \b\b\b\b\b\b\b\b\b\b$i (EC2 => localhost)"
        aws ec2 revoke-security-group-egress \
          --group-id $i \
          --protocol -1 \
          --port all \
          --cidr 0.0.0.0/0
        exit_code_check
      done
    fi
  fi
}

ec2_rule_ingress_add() {
  ec2_lip_fetch # invoke function to fetch localhost EIP

  if [ "$#" -eq 0 ] && [ "$aced_installed" != true ]; then
    echo -e "\n$white \b****  EC2: Authorize Ingress Rule (SSH)  ****"

    echo -e "\n$green \bAdding inbound rule (localhost => EC2): \
    \n\n$blue \bPort: 22 \
    \nFrom: $ip_raw/32 \
    \nTo: EC2 Instance: $ec2_tag"
    aws ec2 authorize-security-group-ingress \
      --group-id $ec2_group_id \
      --protocol tcp \
      --port 22 \
      --cidr $ip_raw/32
    exit_code_check
  elif [ "$1" == "port_update" ]; then
    ec2_rule_revoke inbound_22 # invoke function to revoke inbound rule

    echo -e "\n$green \bAdding new inbound rule (localhost => EC2): \
    \n\n$blue \bPort: $ec2_ssh_port \
    \nFrom: $ip_raw/32 \
    \nTo: EC2 Instance: $ec2_tag"
    aws ec2 authorize-security-group-ingress \
      --group-id $ec2_group_id \
      --protocol tcp \
      --port $ec2_ssh_port \
      --cidr $ip_raw/32
    exit_code_check
  elif [ "$1" == "lip_update" ]; then
    ec2_rule_revoke inbound_$ec2_ssh_port

    echo -e "\n$green \bChecking inbound rules for localhost IP..."
    ec2_inbound_cidr=$(aws ec2 describe-security-groups \
      --group-ids $ec2_group_id \
      --query 'SecurityGroups[0].IpPermissions[].IpRanges[].CidrIp' \
      --output text)
    exit_code_check

    if [ "$ec2_inbound_cidr" != "$ip_raw/32" ]; then
      echo -e "\n$green \bAdding new inbound rule (localhost => EC2): \
      \n\n$blue \bPort: $ec2_ssh_port \
      \nFrom: $ip_raw/32 \
      \nTo: EC2 Instance: $ec2_tag"
      aws ec2 authorize-security-group-ingress \
        --group-id $ec2_group_id \
        --protocol tcp \
        --port $ec2_ssh_port \
        --cidr $ip_raw/32
      exit_code_check
    else
      echo -e "$yellow \nExisting rule for localhost IP already exists!"
    fi
  fi
}

ec2_rule_egress_add(){
  echo -e "\n$white \b****  EC2: Authorize Egress (HTTP/S)  ****"

  echo -e "\n$green \bAdding outbound rule for HTTP traffic: \
  \n\n$blue \bFrom: $aced_nm to anywhere: (0.0.0.0/0)"
  aws ec2 authorize-security-group-egress \
    --group-id $ec2_group_id \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0
  exit_code_check

  echo -e "$green\nAdding outbound rule for HTTPS traffic: \
  \n\n$blue \bFrom: $aced_nm to anywhere: (0.0.0.0/0)"
  aws ec2 authorize-security-group-egress \
    --group-id $ec2_group_id \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0
  exit_code_check
}
