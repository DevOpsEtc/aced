#!/usr/bin/env bash

#####################################################
##  filename:   ec2_health.sh                      ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    EC2 state & health status          ##
##  date:       06/06/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

ec2_state() {
  echo -e "\n$green \bFetching $aced_nm's current state..."
  state=$(aws ec2 describe-instances \
    --instance-ids $ec2_id \
    --query Reservations[].Instances[].State.Name \
    --output text)
  cmd_check

  # title-case string
  state=$(echo $state | awk '{$1=toupper(substr($1,0,1))substr($1,2)}1')

  state_msg=$(echo "$yellow$icon_fail Oops, $ec2_tag is $state"'!'" $reset")
}

ec2_health() {
  ec2_state       # invoke func: fetch $ec2_tag's current state
  case $state in  # change color based on state; used for status icon color
    Running	)	state_color=$green  ;;
    Stopped	)	state_color=$red	  ;;
  esac

  # get total count of instances (ignore terminated)
  ec2_ids=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values= \
    pending,running,shutting-down,stopping,stopped" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text \
    | wc -w)

  eip_ids=$(aws ec2 describe-addresses \
    --query Addresses[*].AllocationId \
    --output text \
    | wc -w)

  if [ $state == "Running" ]; then

    echo -e "\n$green \bFetching AWS system status..."
    system_status=$(aws ec2 describe-instance-status \
      --instance-ids $ec2_id \
    	--query InstanceStatuses[*].SystemStatus[].Status \
    	--output text)
    cmd_check
    [[ $system_status == "ok" ]] && system_status="Reachable"

    echo -e "\n$green \bFetching EC2 instance status..."
    instance_status=$(aws ec2 describe-instance-status \
    	--instance-ids $ec2_id \
    	--query InstanceStatuses[*].InstanceStatus[].Status \
    	--output text)
    cmd_check
    [[ $instance_status == "ok" ]] && instance_status="Reachable"

    ec2_eip_fetch silent # fetch last EIP
    echo -e "\n$green \bFetching IP ping results..."
    if ping -c 1 $ec2_ip_last | grep -q '1 packets received'; then
      cmd_check dash
      ping_ip=$icon_pass
      ip_color=$green
    else
      cmd_check dash
      ping_ip=$icon_fail
      ip_color=$red
    fi

    echo -e "\n$green \bFetching FQDN ping results..."
    if [ "$(dig $os_fqdn +short)" == "$ec2_ip_last" ]; then
      if ping -c 1 $ec2_ip_last | grep -q '1 packets received'; then
        ping_fqdn=$icon_pass
        fqdn_color=$green
      else
        ping_fqdn=$icon_fail
        fqdn_color=$red
      fi
    else
      ping_fqdn="DNS ??"
      fqdn_color=$yellow
    fi
    cmd_check

    echo -e "\n$green \bFetching system uptime..."
    uptime=$(ssh $ssh_alias "uptime -p \
      | sed -e 's/up //' -e 's/hour*/hr/' -e 's/minute*/min/'")
    cmd_check

    echo -e "\n$green \bFetching last login..."
    last_login=$(ssh $ssh_alias "lastlog -u \$USER \
      | tail -1 | awk '{print \$4, \$5, \$6, \$7\" from \"\$3}'")
    cmd_check

    echo -e "\n$green \bFetching processes..."
    processes=$(ssh $ssh_alias "ps -A h | wc -l") \
      && processes_user=$(ssh $ssh_alias "ps U \$USER h | wc -l")
    cmd_check

    echo -e "\n$green \bFetching load averages..."
    top_out=$(ssh $ssh_alias "top -bn1 | head -1")
    cmd_check

    echo -e "\n$green \bFetching user logins..."
    # logins=$(echo $top_out | awk '{print $6,$7}' | sed 's/,//')
    logins=$(ssh $ssh_alias "users | wc -w")
    cmd_check

    echo -e "\n$green \bFetching memory usage..."
    mem=$(ssh $ssh_alias "free -mh | tail -2 | head -1") \
      && free_mem_swp=$(ssh $ssh_alias "free -mh | tail -1")
    cmd_check

    load=$(echo $top_out | awk '{print $10,$11,$12}')
    mem_tot=$(echo $mem | awk '{print $2}')
    mem_used=$(echo $mem | awk '{print $3}')
    mem_free=$(echo $mem | awk '{print $4}')
    mem_free_cached=$(echo $mem | awk '{print $7}')
    mem_swap_use=$(echo $free_mem_swp | awk '{print $3}')

    echo -e "\n$green \bFetching disk usage..."
    disk=$(ssh $ssh_alias "df -h --total" | tail -1)
    cmd_check

    disk_tot=$(echo $disk | awk '{print $2}')
    disk_used=$(echo $disk | awk '{print $3}')
    disk_avail=$(echo $disk | awk '{print $4}')

    echo -e "\n$green \bChecking for package updates..."
    apt_updates=$(ssh $ssh_alias "/usr/lib/update-notifier/apt-check 2>&1")
    cmd_check

    apt_up_reg=$(echo $apt_updates | cut -d ';' -f 1)
    apt_up_sec=$(echo $apt_updates | cut -d ';' -f 2)

    echo -e "\n$green \bFetching system OS release info..."
    rel_desc=$(ssh $ssh_alias "lsb_release -d | awk '{print \$2,\$3,\$4}'") \
    && rel_code=$(ssh $ssh_alias "lsb_release -c | awk '{print \$2}'")
    cmd_check

    echo -e "\n$green \bFetching required reboot..."
    [ -f /var/run/reboot-required ] && req_reboot="yes" || req_reboot="no"
    cmd_check

    echo -e "\n$green \bFetching HTTP status code..."
    http_code=$(curl -s -o /dev/null -w '%{http_code}' https://www.$os_fqdn)
    cmd_check

    echo -e "\n$green \bFetching TLS certificate expiry date..."
    cert_exp=$(ssh $ssh_alias "sudo certbot certificates 2>/dev/null \
      | awk '/Expiry/ {print \$6}'")
    cmd_check
  else
  	msg="Not Reachable"
  	system_status="$msg"
  	instance_status="$msg"
  	ping_ip="$msg"
  	ping_fqdn="$msg"
    local ec2_ip="None"
  fi

  echo
  clear
  echo -e "\n$white \bEC2 Totals: $gray \
    \n______________________________________________________ \
    \nInstances:$blue\t$ec2_ids $gray \
    \nEIPs:$blue\t\t$eip_ids $gray \
    \n______________________________________________________
  "
  echo -e "$white \bReachability: $gray \
    \n______________________________________________________ \
    \nAWS System:$blue\t$system_status $gray\tEIP  Ping: \
      \b\b\b\b\b\b$ip_color$ping_ip $gray \
    \nEC2 Instance:$blue\t$instance_status $gray\tFQDN Ping: \
      \b\b\b\b\b\b$fqdn_color$ping_fqdn $gray \
    \n______________________________________________________
  "
  echo -e "$white \b$aced_nm EC2 Instance: $gray \
    \n______________________________________________________ \
    \nId:$blue\t$ec2_id $gray\tTag:$blue\t$ec2_tag $gray \
    \nEIP:$blue\t$ec2_ip_last $gray\t\tState:$state_color\t$state \
    \n$gray \b______________________________________________________
  "
  echo -e "$white \b$aced_nm EC2 System: $gray \
    \n______________________________________________________ \
    \nSystem:$blue\t\t$rel_desc ($rel_code) $gray \
    \nSys Uptime:$blue\t$uptime $gray \
    \nLast Login:$blue\t$last_login $gray \
    \nUser Logins:$blue\t$logins $gray \
    \nProcesses:$blue\ttotal: $processes ($processes_user \
      \b\b\b\b\b\bowned by $os_user) $gray \
    \nLoad Avg:$blue\t$load (1,5,15 minutes) $gray \
    \nMemory:$blue\t\ttotal: $mem_tot, used: $mem_used, free: $mem_free, \
      \b\b\b\b\b\bfree cached: $mem_free_cached $gray \
    \nSwap Usage:$blue\t$mem_swap_use $gray \
    \nDisk Usage:$blue\ttotal: $disk_tot, used: $disk_used, free: \
      \b\b\b\b\b\b$disk_avail $gray \
    \nPkg Updates:$blue\tregular: $apt_up_reg, security: $apt_up_sec $gray \
    \nReboot Needed:$blue\t$req_reboot $gray \
    \n______________________________________________________
  "
  echo -e "$white \b$aced_nm EC2 HTTP: $gray \
    \n______________________________________________________ \
    \nHTTP Status Code:$blue\t$http_code $gray \
    \nTLS/SSL Expiry:  $blue\t$cert_exp days $gray \
    \n______________________________________________________
  "
  [[ "$1" == "menu" ]] \
  && read -n 1 -s -p "$yellow""Press any key to continue "; clear
} # end func: ec2_health
