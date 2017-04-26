#!/usr/bin/env bash

#####################################################
##  filename:   os_app.sh                          ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    install and config apps            ##
##  date:       04/25/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

os_app() {
  echo -e "\n$white \b****  OS: App-Related Install Tasks  ****"
  os_app_install  # invoke func: update native/install new apps
  os_nginx_config   # invoke func: config native/newly installed apps
}

os_app_install() {
  echo -e "\n$green \bRemote: updating app list & upgrading native apps & \
    \b\b\b\b\b dependencies... "
  echo $blue; ssh -t $ssh_alias " \
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qy install grub-pc \
    && sudo DEBIAN_FRONTEND=noninteractive apt-get -qy \
    -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" \
    update  \
      --allow-downgrades \
      --allow-remove-essential \
      --allow-change-held-packages \
    && sudo DEBIAN_FRONTEND=noninteractive apt-get -qy \
    -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" \
    dist-upgrade \
      --allow-downgrades \
      --allow-remove-essential \
      --allow-change-held-packages"
  cmd_check

  # array of apps to install
  app_install=(
    tree                # pretty recursive directory listing
    htop                # pretty alternative to top
    nginx               # HTTP server to serve static site
    iptables-persistent # persist loading of IPTables rules
    fail2ban            # log monitor (brute-force attacks); trigger IPTable
  )

  # sudo apt-get remove <app>; sudo apt autoremove
  for i in "${app_install[@]}"; do
    echo -e "\n$green \bRemote: installing app: $i... "
    echo $blue; ssh -t $ssh_alias "sudo DEBIAN_FRONTEND=noninteractive \
      apt-get -qq install $i"
    cmd_check
  done
} # end func: os_app_install

os_nginx_config() {
  echo -e "\n$white \b****  OS: Nginx Prep & Config  ****"

  echo -e "\n$green \bRemote: editing Nginx config... "
  ssh $ssh_alias " \
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf_old \
    && sudo sed -i \
      -e '/server_tokens /s/.*# /\t/' \
      -e '/server_names_hash/ s/.*# /\t/' \
      -e '/#mail/,/#\}/d' \
      /etc/nginx/nginx.conf"
  cmd_check

  echo -e "\n$green \bRemote: disabling default server block & removing \
    \b\b\b\bdefault document root... "
  ssh $ssh_alias " \
    sudo rm -rf /etc/nginx/sites-enabled/default \
    && sudo rm -rf /var/www/html"
  cmd_check

  echo -e "\n$green \bRemote: creating document root file structure... "
  ssh $ssh_alias "sudo mkdir -p /var/www/$os_fqdn/{dev,live}/html"
  cmd_check

  sites=("dev" "live")

  for i in "${sites[@]}"; do
    if [ "$i" == "live" ]; then
      doc_root=$os_www_live/html
      doc_root_esc="\/var\/www\/$os_fqdn\/live\/html"
      fqdn_title=$os_fqdn_title
      fqdn=$os_fqdn
      srv_names="$fqdn www.$fqdn"
    elif [ "$i" == "dev" ]; then
      doc_root=$os_www_dev/html
      doc_root_esc="\/var\/www\/$os_fqdn\/dev\/html"
      fqdn_title=$os_fqdn_dev_title
      fqdn=$os_fqdn_dev
      srv_names=$fqdn
    fi

    echo -e "\n$green \bRemote: pushing HTML to document root => $doc_root... "
    echo -e '
    <html>
    <head>
      <style> body {background-color:black; text-align: center} </style>
      <style> h1 {text-align: center; color: orange; padding-top: 20} </style>
    </head>
    <body>
      <h1>Welcome to '"$fqdn_title"'!</h1>
    </body>
    </html>' \
      | ssh $ssh_alias "sudo tee $doc_root/index.html > /dev/null"
    cmd_check

    echo -e "\n$green \bRemote: pushing Nginx server block and enabling \
      \b\b\b\b\b\b\b site $fqdn_title... "
    cat ./build/server_block \
      | sed \
        -e '/######/,/######/d' \
        -e '/## default/,$!d' \
        -e "s/doc_root/$doc_root_esc/g" \
        -e "s/srv_names/$srv_names/" \
      | ssh $ssh_alias " \
      sudo tee /etc/nginx/sites-available/$fqdn &>/dev/null \
      && sudo ln -s /etc/nginx/sites-available/$fqdn /etc/nginx/sites-enabled"
    cmd_check

    if [ "$i" == "live" ]; then
      echo -e "\n$green \bRemote: removing unneeded location directives from \
        \b\b\b\b\b\b\b\b$fqdn_title server block"
      ssh $ssh_alias " \
        sudo sed -i \
          -e '/## dev_auth/,/## dev_auth/d' \
          -e '/## dev_robots/,/## dev_robots/d' \
          -e '/## default/d' \
          -e '/## dev_auth/d' \
          -e '/## dev_robots/d' \
        /etc/nginx/sites-available/$fqdn"
      cmd_check
    elif [ "$i" == "dev" ]; then
      echo -e "\n$green \bRemote: removing default server block from \
        \b\b\b\b\b\b\b\b$fqdn_title... "
      ssh $ssh_alias " \
        sudo sed -i \
          -e '/## default/,/## default/d' \
          -e '/## dev_auth/d' \
          -e '/## dev_robots/d' \
        /etc/nginx/sites-available/$fqdn"
      cmd_check

      echo -e "\n$green \bCreate password for $fqdn_title access: \
      \n\n$gray * Store in secure location, e.g. password manager app!"

      read -rsp $'\n'"$yellow""Enter password: " dev_pass

      echo -e "\n\n$green \bRemote: pushing username ($os_nginx_user_dev) for \
        \b\b\b\b\b\b\b\b$fqdn_title site access..."
      echo -n "$os_nginx_user_dev:" \
        | ssh $ssh_alias "sudo tee /etc/nginx/.dev_pass &>/dev/null"
      cmd_check

      echo -e "\n$green \bRemote: pushing password (hashed) for \
        \b\b\b\b\b\b\b\b$fqdn_title site access... "
      echo "$dev_pass" | openssl passwd -apr1 -stdin \
        | ssh $ssh_alias "sudo tee -a /etc/nginx/.dev_pass &>/dev/null"
      cmd_check
    fi
  done

  echo -e "\n$green \bRemote: checking Nginx config & server block syntax... "
  echo $blue; ssh $ssh_alias "sudo nginx -t"
  cmd_check

  echo -e "\n$green \bRemote: restarting Nginx service... "
  echo $blue; ssh $ssh_alias "sudo service nginx restart"
  cmd_check

  echo -e "\n$yellow \bNginx HTTP server logs are located at: \n$blue \
    \n/var/log/nginx/access.log \
    \n/var/log/nginx/error.log"

  echo -e "\n$yellow \bAccess your new websites at: \n$blue \
    \nLive:\t$os_fqdn_title \
    \nAlias:\twww.$os_fqdn_title \n \
    \nDev:\t$os_fqdn_dev_title \
    \nAlias:\twww.$os_fqdn_dev_title"

  echo -e "\n$green \Opening live website... "
  ec2_eip_fetch silent && open http://$ec2_ip_last
} # end func: os_nginx_config
