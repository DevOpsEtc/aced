#!/usr/bin/env bash

#####################################################
##  filename:   ec2_sec.sh                         ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    EC2 security tasks                 ##
##  date:       04/22/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

ec2_sec() {
  echo -e "\n$white \b****  EC2: Security-Related Install Tasks  ****"
  ec2_keypair          # check/create/key pair/import EC2 public key
  ec2_group_create     # check/create EC2 security group
  ec2_rule_revoke all  # revoke default inbound/outbound rules
  ec2_rule_add         # check/authorize inbound/outbound security rules
}

ec2_rule_list() {
  echo -e "\n$green \bFetching EC2 security group IDs..."
  group_ids=($(aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].[GroupId]' \
    --output text)
  )
  cmd_check

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
} # end func: ec2_rule_list

ec2_keypair() {
  echo -e "\n$green \bWaiting on AWS to accept EC2 commands... "
  aws_waiter EC2 &
  activity_show

  echo -e "$white \b****  Localhost/EC2: Key Pair Creation  ****"

  echo -e "\n$green \bChecking for existing EC2 key pairs..."
  key_pairs=($(aws ec2 describe-key-pairs \
    --query KeyPairs[*].KeyName \
    --output text)
  )
  cmd_check

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
        cmd_check
      else
        echo -e "\n$yellow \bKeeping EC2 key pair!"
      fi
    done
  else
    echo -e "\n$blue \bNo EC2 key pairs found!"
  fi

  echo -e "\n$green \bChecking localhost SSH Agent for $ssh_key_private..."
  if ssh-add -L | grep -q "$aced_keys/$ssh_key_private"; then
    echo -e "\n$blue \bFound $ssh_key_private in SSH Agent... "
    echo -e "\n$green \bRemoving $ssh_key_private from SSH Agent..."
    ssh-add -d $aced_keys/$ssh_key_private &>/dev/null
    cmd_check
  else
    echo -e "\n$blue \bNo SSH Agent entry for $ssh_key_private found!"
  fi

  echo -e "\n$green \bChecking for localhost keypair: $aced_nm... "
  if [ -f $aced_keys/$ssh_key_private ]; then
    echo -e "\n$blue \bFound localhost key pair: $aced_nm!"
    echo -e "\n$green \bDeleting localhost key pair: $aced_nm... "
    rm -f $aced_keys/$ssh_key_private* &>/dev/null
    cmd_check
  else
    echo -e "\n$blue \bNo localhost key pair $aced_nm found!"
  fi

  echo -e "\n$yellow \bLocalhost: create passphrase for new key pair: $gray"
  echo -e '
  * Store in secure location, e.g. password manager app'"!"'
  * 5 character minimum!'

  read -rsp $'\n'"$yellow""Enter passphrase: " ssh_key_pass

  echo -e "\n\n$green \bGenerating localhost key pair... \n $blue\
    \nName: $ssh_key_private \
    \nType: rsa \
    \nBits: 4096 \
    \nFile: $aced_keys/$ssh_key_private $reset"
  ssh-keygen -q -t rsa -b 4096 -C $ssh_key_private -P $ssh_key_pass \
    -f $aced_keys/$ssh_key_private
  cmd_check

  echo -e "\n$green \bSetting file permissions on key pair => 400"
  chmod u=r,go= $aced_keys/*
  cmd_check

  echo -e "\n$green \bSetting file permissions on public key => 644"
  chmod u=rw,go=r $aced_keys/$ssh_key_public
  cmd_check

  echo -e "\n$green \bAdding private key to SSH agent... "
  echo $yellow; /usr/bin/ssh-add -K $aced_keys/$ssh_key_private
  cmd_check

  echo -e "\n$green \bEC2: importing localhost public key... "
  echo $blue; aws ec2 import-key-pair \
    --key-name $ssh_key_public \
    --public-key-material file://$aced_keys/$ssh_key_public
  aws ec2 wait key-pair-exists --key-names "$ssh_key_public" &
  activity_show
  cmd_check
} # end func: ec2_keypair

ec2_group_remove() {
  echo -e "\n$green \bChecking for existing EC2 groups..."
  ec2_groups=($(aws ec2 describe-security-groups \
    --query SecurityGroups[*].GroupName \
    --output text)
  )
  cmd_check

  if [ ${#ec2_groups[@]} -gt 0 ]; then
    for g in "${ec2_groups[@]}"; do
      echo -e "\n$blue \bEC2 group found: $g"

      if [ $g != "default" ]; then
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
          cmd_check

          if [ "$net_interface_status" == "in-use" ]; then
            echo -e "\n$blue \bNetwork interface found!"

            echo -e "\n$green \bFetching instance ID..."
            instance_id=$(aws ec2 describe-network-interfaces \
              --filters Name=group-name,Values=$g \
              --query 'NetworkInterfaces[*].Attachment[].InstanceId' \
              --output text)
            cmd_check

            echo -e "\n$yellow \bCan't remove $g while associated with instance \
            \b\b\b\b\b\b\b\b\b\b\b\bID: $instance_id"

            notify instance # display notes

            decision_response Terminate instance: $instance_id?
            [[ "$response" =~ [yY] ]] && ec2_terminate $instance_id || return
          else
            echo -e "\n$blue \bNo network interface found!"
          fi

          echo -e "\n$green \bDeleting EC2 group: $g..."
          aws ec2 delete-security-group --group-name "$g"
          cmd_check
        else
          echo -e "\n$yellow \bKeeping EC2 group: $g!"
        fi
      fi
    done
  else
    echo -e "\n$blue \bNo EC2 group found!"
  fi
} # end func: ec2_group_remove

ec2_group_create() {
  echo -e "\n$white \b****  EC2: Security Group Creation  ****"

  ec2_group_remove

  echo -e "\n$green \bFetching VPC ID... $blue"
  ec2_vpc_id=$(aws ec2 describe-vpcs \
    --query Vpcs[*].VpcId \
    --output text)
  cmd_check

  aced_cfg_push ec2_vpc_id

  echo -e "\n$green \bCreating EC2 group: $ec2_group... $blue"
  ec2_group_id=$(aws ec2 create-security-group \
    --group-name $ec2_group \
    --description "$ec2_group_desc" \
    --vpc-id $ec2_vpc_id \
    --output text)
  cmd_check

  aced_cfg_push ec2_group_id
}

ec2_rule_revoke() {
  argument_check
  lip_fetch last
  if [ "$1" == "inbound_22" ]; then
    echo -e "\n$green \bEC2: revoking inbound rule (EC2 <= localhost): \
    \n\n$blue \bPort: 22 (TCP: SSH) \
    \nFrom: $lip_last"
    aws ec2 revoke-security-group-ingress \
      --group-id $ec2_group_id \
      --protocol tcp \
      --port 22 \
      --cidr $lip_last
    cmd_check
  elif [ "$1" == "inbound_$os_ssh_port" ]; then
    echo -e "\n$green \bEC2: revoking inbound rule (EC2 <= localhost): \
      \n\n$blue \bPort: $os_ssh_port (TCP: SSH) \
      \nFrom: $lip_last"
    aws ec2 revoke-security-group-ingress \
      --group-id $ec2_group_id \
      --protocol tcp \
      --port $os_ssh_port \
      --cidr $lip_last
    cmd_check
  elif [ "$1" == "all" ]; then
    echo -e "\n$green \bFetching default security group ID..."
    group_id_def=$(aws ec2 describe-security-groups \
      --filters 'Name=group-name,Values=default' \
      --query 'SecurityGroups[*].GroupId' \
      --output text)
    cmd_check

    echo -e "\n$green \bRevoking default inbound \"All\" rule on group ID: \
      \n\n$blue \b$group_id_def (EC2 <= localhost)"
    aws ec2 revoke-security-group-ingress \
      --group-id $group_id_def \
      --protocol -1 \
      --port all \
      --cidr 0.0.0.0/0
    cmd_check

    echo -e "\n$green \bFetching all EC2 security group IDs..."
    sec_groups=($(aws ec2 describe-security-groups \
      --query 'SecurityGroups[*].GroupId' \
      --output text)
    )
    cmd_check

    if [ "${#sec_groups[@]}" -gt 0 ]; then
      for i in "${sec_groups[@]}"; do
        echo -e "\n$green \bRevoking default outbound \"All\" rule on group \
        \b\b\b\b\b\b\b\bID: \n\n$blue \b$i (EC2 <= localhost)"
        aws ec2 revoke-security-group-egress \
          --group-id $i \
          --protocol -1 \
          --port all \
          --cidr 0.0.0.0/0
        cmd_check
      done
    fi
  fi
} # end func: ec2_rule_revoke

ec2_rule_add() {
  if [ "$#" -eq 0 ] && [ "$aced_ok" != true ]; then
    lip_fetch last # invoke func: fetch raw localhost IP

    echo -e "\n$green EC2: Authorizing Ingress Rules (EC2 <= localhost):
    $blue
    TCP \t(SSH) \t\tport 22 \tcidr: $localhost_ip/32 (temporary)
    TCP \t(SSH) \t\tport $os_ssh_port \tcidr: $localhost_ip/32
    ICMP \t(Echo) \t\tport 8-1 \tcidr: 0.0.0.0/0
    TCP \t(HTTP) \t\tport 80 \tcider: 0.0.0.0/0, ::/0 (IPv4/IPv6)
    TCP \t(HTTPS) \tport 443 \tcider: 0.0.0.0/0, ::/0 (IPv4/IPv6)"
    aws ec2 authorize-security-group-ingress \
      --group-id $ec2_group_id \
      --ip-permissions '[
        {
          "IpProtocol": "tcp",
          "FromPort": 22, "ToPort": 22,
          "IpRanges": [{"CidrIp": "'$lip_last'"}]
        },
        {
          "IpProtocol": "tcp",
          "FromPort": '$os_ssh_port', "ToPort": '$os_ssh_port',
          "IpRanges": [{"CidrIp": "'$lip_last'"}]
        },
        {
          "IpProtocol": "icmp",
          "FromPort": 8, "ToPort": -1,
          "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
          "Ipv6Ranges": [{"CidrIpv6": "::/0"}]
        },
        {
          "IpProtocol": "tcp",
          "FromPort": 80, "ToPort": 80,
          "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
          "Ipv6Ranges": [{"CidrIpv6": "::/0"}]
        },
        {
          "IpProtocol": "tcp",
          "FromPort": 443, "ToPort": 443,
          "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
          "Ipv6Ranges": [{"CidrIpv6": "::/0"}]
        }
      ]'
    cmd_check

    echo -e "\n$green EC2: Authorizing Egress Rules (EC2 <= localhost):
    $blue
    ICMP \t(Echo) \t\tport 8-1 \tcidr: 0.0.0.0/0
    TCP \t(HTTP) \t\tport 80 \tcider: 0.0.0.0/0, ::/0 (IPv4/IPv6)
    TCP \t(HTTPS) \tport 443 \tcider: 0.0.0.0/0, ::/0 (IPv4/IPv6)"
    aws ec2 authorize-security-group-egress \
      --group-id $ec2_group_id \
      --ip-permissions '[
        {
          "IpProtocol": "icmp",
          "FromPort": 8, "ToPort": -1,
          "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
          "Ipv6Ranges": [{"CidrIpv6": "::/0"}]
        },
        {
          "IpProtocol": "tcp",
          "FromPort": 80, "ToPort": 80,
          "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
          "Ipv6Ranges": [{"CidrIpv6": "::/0"}]
        },
        {
          "IpProtocol": "tcp",
          "FromPort": 443, "ToPort": 443,
          "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
          "Ipv6Ranges": [{"CidrIpv6": "::/0"}]
        }
      ]'
    cmd_check
  elif [ "$1" == "port_update" ]; then
    ec2_rule_revoke inbound_22
  elif [ "$1" == "lip_update" ]; then
    ec2_rule_revoke inbound_$os_ssh_port

    echo -e "\n$green \bEC2: checking inbound rules for localhost IP..."
    ec2_inbound_cidr=$(aws ec2 describe-security-groups \
      --group-ids $ec2_group_id \
      --query 'SecurityGroups[0].IpPermissions[].IpRanges[].CidrIp' \
      --output text)
    cmd_check

    lip_fetch # fetch latest localhost IP

    if [ "$ec2_inbound_cidr" != "$localhost_ip/32" ]; then
      echo -e "\n$green \bAdding new inbound rule (localhost => EC2): \
        \n\n$blue \bPort: $os_ssh_port (TCP: SSH) \
        \nFrom: $localhost_ip/32"
      aws ec2 authorize-security-group-ingress \
        --group-id $ec2_group_id \
        --protocol tcp \
        --port $os_ssh_port \
        --cidr $localhost_ip/32
      cmd_check
    else
      echo -e "$yellow \nExisting rule for localhost IP already exists!"
    fi
  fi
} # end func: ec2_rule_add
