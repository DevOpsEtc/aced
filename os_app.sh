#!/usr/bin/env bash

#####################################################
##  filename:   os_app.sh                          ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    install and config apps            ##
##  date:       06/11/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

os_app() {
  echo -e "\n$white \b****  OS: App-Related Install Tasks  ****"
  os_apt_update       # invoke func: update packages lists & native packages
  os_apt_install      # invoke func: install new packages
  os_nginx_config     # invoke func: config HTTP server
  os_fail2ban_config  # invoke func: config log monitor/ip banner
}

os_apt_update() {
  echo -e "\n$green \bRemote: adding PPA, updating app list & upgrading \
    \b\b\b\b\b native apps/dependencies... "
  echo $blue; ssh $ssh_alias " \
    sudo DEBIAN_FRONTEND=noninteractive add-apt-repository -y \
      ppa:certbot/certbot \
    && sudo DEBIAN_FRONTEND=noninteractive apt-get update -qy \
    && sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -qy \
      --allow-downgrades \
      --allow-remove-essential \
      --allow-change-held-packages"
  cmd_check
}

os_apt_install() {
  install_pkg=(
    tree                # pretty recursive directory listing
    htop                # pretty alternative to top
    nginx               # HTTP server to serve static site
    certbot             # client for certificate authority: Let's Encrypt
    iptables-persistent # persist loading of IPTables rules
    fail2ban            # log monitor (brute-force attacks); trigger IPTable
  )

  # sudo apt-get remove <app>; sudo apt autoremove
  for i in "${install_pkg[@]}"; do
    echo -e "\n$green \bRemote: installing app: $i... "
    echo $blue; ssh $ssh_alias " \
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy $i"
    cmd_check
  done
} # end func: os_apt_install

os_nginx_config() {
  echo -e "\n$white \b****  OS: Nginx Config & HTML Placeholders  ****"

  echo -e "\n$green \bRemote: backing up & editing Nginx config... "
  ssh $ssh_alias " \
    sudo cp -f /etc/nginx/{nginx.conf,nginx.conf.old} \
    && sudo sed -i \
      -e '/server_tokens /s/.*# /\t/' \
      -e '/server_names_hash/ s/.*# /\t/' \
      -e '/server_names_hash/ s/64/128/' \
      -e '/#mail/,/#\}/d' \
      /etc/nginx/nginx.conf"
  cmd_check

  # bug workaround: https://bugs.launchpad.net/ubuntu/+source/nginx/+bug/1581864
  echo -e "\n$green \bRemote: pushing systemd override config for nginx... "
  ssh $ssh_alias " \
    sudo mkdir /etc/systemd/system/nginx.service.d \
    && printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" \
      | sudo tee /etc/systemd/system/nginx.service.d/override.conf > /dev/null \
    && sudo systemctl daemon-reload \
    && sudo systemctl restart nginx"
  cmd_check

  echo -e "\n$green \bRemote: disabling default server block & removing \
    \b\b\b\bdefault document root... "
  ssh $ssh_alias " \
    sudo rm -rf /etc/nginx/sites-enabled/default \
    && sudo rm -rf /var/www/public"
  cmd_check

  echo -e "\n$green \bRemote: creating document root file structure... "
  ssh $ssh_alias "sudo mkdir -p /var/www/$os_fqdn/{dev,live}/public"
  cmd_check

  sites=("dev" "live")

  for i in "${sites[@]}"; do
    if [ "$i" == "live" ]; then
      doc_root=$os_www_live/public
      doc_root_esc="\/var\/www\/$os_fqdn\/live\/public"
      fqdn_title=$os_fqdn_title
      fqdn=$os_fqdn
      srv_names="$fqdn www.$fqdn"
    elif [ "$i" == "dev" ]; then
      doc_root=$os_www_dev/public
      doc_root_esc="\/var\/www\/$os_fqdn\/dev\/public"
      fqdn_title=$os_fqdn_dev_title
      fqdn=$os_fqdn_dev
      srv_names=$fqdn
    fi

    echo -e "\n$green \bRemote: pushing test index.html to $doc_root... "
    echo -e "Welcome to $fqdn_title" \
      | ssh $ssh_alias "sudo tee $doc_root/index.html > /dev/null"
    cmd_check

    echo -e "\n$green \bRemote: pushing Nginx server block and enabling \
      \b\b\b\b\b\b\b site $fqdn_title... "
    cat ./build/server_block \
      | sed \
        -e '/^######/,/^######/d' \
        -e '/## pre-cert/,$!d' \
        -e "s/srv_names/$srv_names/g" \
        -e "s/os_fqdn/$os_fqdn/" \
        -e "s/fqdn/$fqdn/" \
        -e "s/doc_root/$doc_root_esc/" \
      | ssh $ssh_alias " \
      sudo tee /etc/nginx/sites-available/$fqdn > /dev/null \
      && sudo ln -sf /etc/nginx/sites-available/$fqdn /etc/nginx/sites-enabled"
    cmd_check

    echo -e "\n$green \bRemote: post-push server block clean up... "
    if [ "$i" == "live" ]; then
      # e1: kill dev site block; e3: kill header
      ssh $ssh_alias " \
        sudo sed -i \
          -e '/post-cert-dev/,/post-cert-dev/d' \
          -e '/dev site/,/dev site/d' \
          -e '/live site/d' \
        /etc/nginx/sites-available/$fqdn"
      cmd_check
    elif [ "$i" == "dev" ]; then
      # e1: kill default_server; ec2: kill live site block; e3: kill header
      ssh $ssh_alias " \
        sudo sed -i \
          -e '/listen/ s/ default_server//' \
          -e '/## post-cert-live/,/## post-cert-live/d' \
          -e '/## live site/,/## live site/d' \
          -e '/## dev site/d' \
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

  echo -e "\n$green \bRemote: checking Nginx config/server block syntax & \
    \b\b\b\brestarting service... $reset \n"
  ssh $ssh_alias "sudo nginx -t && sudo service nginx restart"
  cmd_check

  echo -e "\n$yellow \bNginx HTTP server logs are located at: \n$blue \
    \n/var/log/nginx/access.log \
    \n/var/log/nginx/error.log"

  echo -e "\n$yellow \bAccess your new websites at: \n$blue \
    \nLive:\twww.$os_fqdn_title\nDev:\t$os_fqdn_dev_title"
} # end func: os_nginx_config

os_fail2ban_config() {
  echo -e "\n$white \b****  OS: Fail2ban Config & Jail Setup  ****"

  echo -e "\n$green \bRemote: pushing Fail2ban conf to local override... "
  echo -e "[Definition] \
    \nloglevel = INFO \
    \nlogtarget = /var/log/fail2ban.log \
    \nsyslogsocket = auto \
    \nsocket = /var/run/fail2ban/fail2ban.sock \
    \npidfile = /var/run/fail2ban/fail2ban.pid \
    \ndbfile = /var/lib/fail2ban/fail2ban.sqlite3 \
    \ndbpurgeage = 86400" \
    | ssh $ssh_alias "sudo tee /etc/fail2ban/fail2ban.local &>/dev/null"
  cmd_check

  echo -e "\n$green \bRemote: pushing Fail2ban jail conf to local override... "
  echo $blue; cat ./build/jail.local \
    | sed \
      -e '/^######/,/^######/d' \
      -e '/[DEFAULT]/,$!d' \
      -e "s/os_ssh_port/$os_ssh_port/" \
    | ssh $ssh_alias "sudo tee /etc/fail2ban/jail.local &>/dev/null"
  cmd_check

  jail_filters=(
    "nginx-http-auth" # ban requests for auth failures
    "nginx-badbots"   # ban requests from blacklisted bots
    "nginx-noscript"  # ban requests for non-used script extensions
    "nginx-nohome"    # ban requests for www docs in home
    "nginx-noproxy"   # ban requests for proxy use of website
    )

  for j in "${jail_filters[@]}"; do
    echo -e "$green\nRemote: pushing Fail2ban jail filter: $j... "
    if [ "$j" == "nginx-http-auth" ]; then
      fail_regex='\\t \ \ \ ^ \\\[error\\\] \\\d+#\\\d+: \\\*\\\d+ no user/pass
        provided, client: <HOST>, server: \\\S+, request: \"\\\S+ \\\S+
        HTTP\/\\\d+\\\.\\\d+\", host: \"\\\S+\"\\\s*\$'
      ssh $ssh_alias "sudo sed -i '/failregex/a "$fail_regex"' \
      /etc/fail2ban/filter.d/$j.conf &>/dev/null"
    elif [ "$j" == "nginx-badbots" ]; then
      ssh $ssh_alias "sudo cp -f \
        /etc/fail2ban/filter.d/{apache-badbots.conf,$j.conf}"
    else
      if [ "$j" == "nginx-noscript" ]; then
        fail_regex='^<HOST> -.*GET.*(\.php|\.asp|\.exe|\.pl|\.cgi|\.scgi)'
      elif [ "$j" == "nginx-nohome" ]; then
        fail_regex='^<HOST> -.*GET .*/~.*'
      elif [ "$j" == "nginx-noproxy" ]; then
        fail_regex='^<HOST> -.*GET http.*'
      fi
      echo -e "[Definition] \nfailregex = $fail_regex \nignoreregex =" \
        | ssh $ssh_alias "sudo tee /etc/fail2ban/filter.d/$j.conf &>/dev/null"
    fi
    cmd_check
  done

  echo -e "\n$green \bRemote: restarting Fail2ban service & fetching jails... "
  echo $blue; ssh $ssh_alias " \
  sudo service fail2ban restart && sudo fail2ban-client status"
  cmd_check
}
