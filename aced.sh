#!/usr/bin/env bash

#############################################################
##  filename:   aced.sh                                    ##
##  path:       ~/src/deploy/cloud/aws/                    ##
##  purpose:    run ACED: Automated EC2 Deploy             ##
##  date:       06/12/2017                                 ##
##  symlink:    $ ln -s ~/src/deploy/cloud/aws ~/aced/app  ##
##  repo:       https://github.com/DevOpsEtc/aced          ##
##  clone path: ~/aced/app/                                ##
##  execute:    $ ~/aced/app/aced.sh                       ##
##  run:        $ aced                                     ##
##  options:    -connect -help -eip -lip -off -on          ##
##  options:    -reboot -status -uninstall -ver            ##
#############################################################

version() {
  echo "$blue
        ___   _____  _____ ______
       / _ \ /  __ \|  ___||  _  \\
      / /_\ \| /  \/| |__  | | | |
      |  _  || |    |  __| | | | |
      | | | || \__/\| |___ | |/ /
      \_| |_/ \____/\____/ |___/

        AWS Cloud Easy Deploy

        Version:  $aced_ver
        Released: $aced_rel
        Author:   DevOps /etc
  $reset"
}

aced_help() {
  echo -e "\n$yellow
    ACED Commands: \n
    $ aced                    # show ACED task menu
    $ aced -a or --admin      # show ACED admin task menu
    $ aced -c or --connect    # connect to ACED via SSH
    $ aced -d or --down       # stop ACED instance
    $ aced -e or --eip        # fetch ACED public IP address
    $ aced -h or --help       # show ACED help (this list)
    $ aced -i or --ip         # fetch localhost public IP address
    $ aced -l or --log        # fetch remote OS tailed logs
    $ aced -m or --maint      # toggle www maintenance mode
    $ aced -r or --reboot     # reboot ACED instance
    $ aced -s or --status     # show ACED health status
    $ aced -u or --up         # start ACED instance
    $ aced -v or --version    # show ACED version information
    $ aced -t or --tls        # request new/revoke old web certificate
    $ aced --rebuild          # rebuild instance with same eip & web certs
    $ aced --uninstall        # uninstall ACED
  $reset"
}

admin_menu() {
  ec2_state # check state; bail if not running
  [[ "$state" != "Running" ]] && { echo -e "\n$state_msg"; return; }

  # menu options array
  admin_item=(
    "Web Maintenance Mode"
    "Web Certificates"
    "OS Fail2ban Bans"
    "OS Fail2ban Jails"
    "OS IPTables Drops"
    "OS IPTables Rules"
    "OS Main Logs"
    "OS Main Ports"
    "OS Main Processes"
    "OS Main Services"
    "OS Net Services"
    "OS Package Updates"
    "OS Pass-less Sudo"
    "DNS Host Records"
    "EC2 Sec Group Rules"
    "⇑ Task Menu"
    "✘ QUIT"
  )

  while true; do  # keep redrawing menu until QUIT
    clear
    unset COLUMNS  # force default menu layout
    echo -e "\n\n$white \b$aced_nm Admin Tasks $gray \
    \n_______________________________________________________________________"
    PS3=$'\n'"$yellow"'Choose task number: '"$reset"
    select admin in "${admin_item[@]}"; do
      case $admin in
        "Web Maintenance Mode" ) web_mm menu;           break ;;
        "Web Certificates"     ) os_admin certs;        break ;;
        "OS Fail2ban Bans"     ) os_admin bans;         break ;;
        "OS Fail2ban Jails"    ) os_admin jails;        break ;;
        "OS IPTables Drops"    ) os_admin drops;        break ;;
        "OS IPTables Rules"    ) os_admin rules;        break ;;
        "OS Main Logs"         ) os_admin logs;         break ;;
        "OS Main Ports"        ) os_admin ports;        break ;;
        "OS Main Processes"    ) os_admin processes;    break ;;
        "OS Main Services"     ) os_admin services;     break ;;
        "OS Net Services"      ) os_admin net_services; break ;;
        "OS Package Updates"   ) os_admin updates;      break ;;
        "OS Pass-less Sudo"    ) sudo_pass menu;        break ;;
        "DNS Host Records"     ) os_admin dns;          break ;;
        "EC2 Sec Group Rules"  ) ec2_rule_list;         break ;;
        "⇑ Task Menu"          ) task_menu;             break ;;
        "✘ QUIT"               ) return;                      ;;
      esac
    done
  done
} # end func: admin_menu

task_menu() {
  task_item=(
    "Connect $aced_nm"
    "Reboot $aced_nm"
    "$aced_nm Health"
    "Stop $aced_nm"
    "Start $aced_nm"
    "⇓ Admin Menu"
    "✘ QUIT"
  )

  while true; do
    clear
    COLUMNS=20 # force vertical menu layout
    echo -e "\n\n$white \b$aced_nm Tasks $gray \
      \n_______________"
    PS3=$'\n'"$yellow"'Choose task number: '"$reset"
    select task in "${task_item[@]}"; do
      case $task in
        "Connect $aced_nm"   ) ec2_connect menu;  break ;;
        "Reboot $aced_nm"    ) ec2_reboot menu;   break ;;
        "$aced_nm Health"    ) ec2_health menu;   break ;;
        "Stop $aced_nm"      ) ec2_stop menu;     break ;;
        "Start $aced_nm"     ) ec2_start menu;    break ;;
        "⇓ Admin Menu"       ) admin_menu;        break ;;
        "✘ QUIT"             ) return;                  ;;
      esac
    done
  done
} # end func: task_menu

main() {
  ############################################################
  ####  Main ACED function: install || display task menu  ####
  ############################################################

  # bail if not run from MacOS or if aws-cli not found
  [[ $(uname) == "Darwin" ]] || { echo -e "MacOS Not Found!"; exit 1; }
  type -p aws >/dev/null || { echo -e "AWS CLI Not Found!"; exit 1; }

  # set shell option enabling alias expansion for alias test; source aliases
  shopt -s expand_aliases && . $HOME/.bash_profile

  cd "$(dirname $0)" || exit 1  # set path of ACED scripts
                                 # ⇓ source scripts ⇓
  . ./config.sh                 # ACED default & placeholder config
  . ./misc.sh                   # ACED helper tasks
  . ./aws.sh                    # AWS waiter & config tasks
  . ./iam.sh                    # IAM security related tasks
  . ./ec2_sec.sh                # EC2 security related tasks
  . ./ec2.sh                    # EC2 instance related tasks
  . ./ec2_health.sh             # EC2 instance health related tasks
  if [ "$aced_ok" != true ]; then
    . ./os_sec.sh               # OS security related tasks
    . ./os_app.sh               # OS app related tasks
    . ./os_misc.sh              # OS one-off tasks
  fi

  if [ "$aced_ok" != true ]; then
    clear
    version     # invoke func to display ACED release info
    sleep 2
    echo -e "\n$white \b****  $aced_nm: Install  ****"
    echo -e "\n$green \bCreating file structure... "
    mkdir -p $aced_root/config/backups/{aws,certs,ssh},keys
    cmd_check   # invoke func: check last command status code
    iam         # invoke func: check/install IAM group/user/policy
    ec2_sec     # invoke func: check/install EC2 key pair/group/rules
    ec2         # invoke func: check/install EC2 instance/EIP
    os_sec      # invoke func: create user/push key/harden on OS
    os_app      # invoke func: update/install/config apps on OS
    os_misc     # invoke func: do one-off tasks on OS
    os_sec_post # invoke func: run commands that needed more time
    ec2_reboot  # invoke func: cross fingers & reboot EC2 instance

    if ! alias $ssh_alias > /dev/null; then
      echo -e "\n$green \bCreating permanent alias: $ec2_tag"
      echo "alias $ec2_tag='$aced_app/aced.sh'" >> $HOME/.bash_profile
      cmd_check
    fi

    . $HOME/.bash_profile  # sourced 2nd time to pickup new ACED alias
    aced_ok=true           # set value for final result of ACED install
    aced_cfg_push aced_ok  # invoke func: update ACED default config value
    echo "$blue
    *************************
    ***  $aced_nm Installed!  ***
    *************************"
    notify eip             # DNS host record info
    notify cert            # TLS/SSL certificate info
    echo -e "\n$yellow \bEnter $ $aced_nm_low or $ $aced_nm_low --help $reset"
    exit 0                 # exit without error
  fi

  option=${1//-}  # strip off any prefixed hypens from argument

  case $option in  # ACED parameter conditionals; bypass ACED task menu
    a|admin     ) admin_menu        ;; # show ACED admin task menu
    c|connect   ) ec2_connect       ;; # access instance via SSH
    d|down      ) ec2_stop          ;; # stop instance
    e|eip       ) ec2_eip_fetch ls  ;; # fetch public IP address
    h|help      ) aced_help         ;; # show ACED help
    i|ip        ) ip_fetch ls       ;; # fetch localhost public IP address
    l|log       ) os_admin logs     ;; # fetch remote OS tailed logs
    m|maint     ) web_mm            ;; # toggle www maintenance mode
    r|reboot    ) ec2_reboot        ;; # reboot instance
    u|up        ) ec2_start         ;; # start instance
    s|status    ) ec2_health        ;; # show full AWS/EC2/ACED status
    uninstall   ) uninstall         ;; # remove ACED payload & settings
    v|version   ) version           ;; # show ACED version info
    t|tls       ) cert_get          ;; # request new/revoke old web certificate
    rebuild     ) ec2_rebuild       ;; # relaunch instance; old web certs & EIP
    *           ) task_menu         ;; # show ACED task menu: wildcard args
  esac
} # end func: main

main "$@" # invoke main ACED function; ingest arguments as written
