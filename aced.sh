#!/usr/bin/env bash

#############################################################
##  filename:   aced.sh                                    ##
##  path:       ~/src/deploy/cloud/aws/                    ##
##  purpose:    run ACED: Automated EC2 Deploy             ##
##  date:       04/22/2017                                 ##
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

    AWS Cloud Environment Deployment

      Version:  $aced_ver
      Released: $aced_rel
      Author:   DevOps /etc
  $reset"
}

aced_help() {
  echo -e "\n$yellow
    ACED Commands: \n
    $ aced                    # show ACED task menu
    $ aced -c or --connect    # connect to ACED via SSH
    $ aced -d or --down       # stop ACED instance
    $ aced -e or --eip        # fetch ACED public IP address
    $ aced -h or --help       # show ACED help (this list)
    $ aced -l or --lip        # fetch localhost public IP address
    $ aced -r or --reboot     # reboot ACED instance
    $ aced -s or --status     # show ACED health status
    $ aced -u or --up         # start ACED instance
    $ aced -v or --version    # show ACED version information
    $ aced --uninstall        # uninstall ACED
  $reset"
}

task_menu() {
  ##########################################################
  ####  Display AWS IAM & EC2 task menu  ###################
  ##########################################################
  # menu options array
  task_item=(
    "Connect $aced_nm"
    "Reboot $aced_nm"
    "EC2 Health Status"
    "Stop $aced_nm"
    "Start $aced_nm"
    "EC2 IP Address"
    "EC2 Group Rules"
    "Rotate IAM Keys"
    "Rotate EC2 Keypair"
    "Rotate EC2 EIP"
    "QUIT"
  )

  clear
  while true; do  # keep redrawing menu until QUIT
    # COLUMNS=20  # force vertical menu layout
    echo -e "\n\n$white \b$aced_nm Tasks $gray \
      \n______________________________________________________"
    PS3=$'\n'"$yellow"'Choose task number: '"$reset"
    select task in "${task_item[@]}"; do
      case $task in
        "Connect $aced_nm"   ) ec2_connect;       break ;;
        "Reboot $aced_nm"    ) ec2_reboot;        break ;;
        "EC2 Health Status"  ) ec2_health menu;   break ;;
        "Stop $aced_nm"      ) ec2_stop;          break ;;
        "Start $aced_nm"     ) ec2_start;         break ;;
        "EC2 IP Address"     ) ec2_eip_fetch ls;  break ;;
        "EC2 Group Rules"    ) ec2_rule_list;     break ;;
        "Rotate IAM Keys"    ) iam_keys_rotate;   break ;;
        "Rotate EC2 Keypair" ) ec2_keypair;       break ;;
        "Rotate EC2 EIP"     ) ec2_eip_rotate;    break ;;
        "QUIT"               ) exit 0;                  ;;
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
  . ./os_sec.sh                 # OS security related tasks
  . ./os_app.sh                 # OS app related tasks
  . ./os_misc.sh                # OS one-off tasks
  # . ./os_data.sh                # OS file related tasks

  if [ "$aced_ok" != true ]; then
    clear
    version       # invoke func to display ACED release info
    sleep 2
    echo -e "\n$white \b****  $aced_nm: Install  ****"
    echo -e "\n$green \bCreating file structure... "
    mkdir -p $aced_root/{config/{backups/{aws,ssh},keys},src/blog}
    cmd_check   # invoke func: check last command status code
    iam         # invoke func: check/install IAM group/user/policy
    ec2_sec     # invoke func: check/install EC2 key pair/group/rules
    ec2         # invoke func: check/install EC2 instance/EIP
    os_sec      # invoke func: create user/push key/harden on OS
    os_app      # invoke func: update/install/config apps on OS
    os_misc     # invoke func: do one-off tasks on OS
    # os_data     # invoke func: deployment tasks on OS
    # os_hard_act # invoke func: lock default OS account; kill password-less sudo
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
    notify eip             # invoke func to display info RE: DNS host record
    echo -e "\n$yellow \bEnter $ $aced_nm_low or $ $aced_nm_low --help $reset"
    exit 0         # exit without error
  fi

  option=${1//-}  # strip off any prefixed hypens from argument

  case $option in  # ACED parameter conditionals; bypass ACED task menu
    c|connect   ) ec2_connect       ;; # access instance via SSH
    e|eip       ) ec2_eip_fetch ls  ;; # fetch public IP address
    h|help      ) aced_help         ;; # show ACED help
    l|lip       ) lip_fetch ls      ;; # fetch localhost public IP address
    d|down      ) ec2_stop          ;; # stop instance
    r|reboot    ) ec2_reboot        ;; # reboot instance
    u|up        ) ec2_start         ;; # start instance
    s|status    ) ec2_health        ;; # show full AWS/EC2/ACED status
    uninstall   ) uninstall         ;; # remove ACED payload & settings
    v|version   ) version           ;; # show ACED version info
    *           ) task_menu         ;; # show ACED task menu: wildcard args
  esac
} # end func: main

main "$@" # invoke main ACED function; ingest arguments as written
