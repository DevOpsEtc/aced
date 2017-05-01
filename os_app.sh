#!/usr/bin/env bash

#####################################################
##  filename:   os_app.sh                          ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    install and config apps            ##
##  date:       05/01/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

os_app() {
  echo -e "\n$white \b****  OS: App-Related Install Tasks  ****"
  os_apt_update   # invoke func: update packages lists & native packages
  os_apt_install  # invoke func: install new packages
  os_nginx_config # invoke func: config native/newly installed apps
}

os_apt_update() {
  echo -e "\n$green \bRemote: adding PPA, updating app list & upgrading \
    \b\b\b\b\b native apps/dependencies... "
  echo $blue; ssh -t $ssh_alias " \
    sudo DEBIAN_FRONTEND=noninteractive apt-get -qy install grub-pc \
    && sudo DEBIAN_FRONTEND=noninteractive add-apt-repository \
      ppa:certbot/certbot \
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
    echo $blue; ssh -t $ssh_alias " \
      sudo DEBIAN_FRONTEND=noninteractive apt-get -qq install $i"
    cmd_check
  done
} # end func: os_apt_install

os_nginx_config() {
  echo -e "\n$white \b****  OS: Nginx Prep & Config  ****"

  echo -e "\n$green \bRemote: editing Nginx config... "
  ssh $ssh_alias " \
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf_old \
    && sudo sed -i \
      -e '/server_tokens /s/.*# /\t/' \
      -e '/server_names_hash/ s/.*# /\t/' \
      -e '/server_names_hash/ s/64/128/' \
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

    html_pages=("index" "503" "404" "401")
    cmd="\$ curl -Is --http2 https:\/\/www.$os_fqdn"

    for h in "${html_pages[@]}"; do
      if [ "$h" == "index" ]; then
        content_title="Welcome to $fqdn_title!"
        content_cmd="$cmd | awk \/HTTP\/"
        content_out='HTTP\/2.0 200 OK'
        content_pre=$content_title
        content_code='Status Code: 200...'
        content_post='Looks good from here!'
      elif [ $h == "503" ]; then
        content_title='Maintenance Mode'
        content_cmd="$cmd | awk \/HTTP\/"
        content_out='HTTP\/2.0 503 OK'
        content_pre='drat, drat and double drat!'
        content_code='status code: 503...'
        content_post='you caught us fixing stuff!'
      elif [ $h == "404" ]; then
        content_title='Missing Link?'
        content_cmd="$cmd\/missing_link | awk \/HTTP\/"
        content_out='HTTP\/2.0 404 Not Found'
        content_pre='darn darn darn darny darn!'
        content_code='status code: 404...'
        content_post='we knew we forgot something!'
      elif [ $h == "401" ]; then
        content_title='Test Site'
        content_cmd="\$ curl -Is --http2 https:\/\/dev.$os_fqdn | awk \/HTTP\/"
        content_out='HTTP\/2.0 401 Authorization Required'
        content_pre='really?!'
        content_code='status code: 401...'
        content_post='move along, nothing to see here'
      fi

      echo -e "\n$green \bRemote: pushing $h.html to $doc_root... "
      cat ./build/html \
        | sed \
          -e "s/content_title/$content_title/" \
          -e "s/content_cmd/$content_cmd/" \
          -e "s/content_out/$content_out/" \
          -e "s/content_pre/$content_pre/" \
          -e "s/content_code/$content_code/" \
          -e "s/content_post/$content_post/" \
        | ssh $ssh_alias "sudo tee $doc_root/$h.html > /dev/null"
      cmd_check
    done

    echo -e "\n$green \bRemote: pushing Nginx server block and enabling \
      \b\b\b\b\b\b\b site $fqdn_title... "
    cat ./build/server_block \
      | sed \
        -e '/^######/,/^######/d' \
        -e '/## pre-cert/,$!d' \
        -e "s/srv_names/$srv_names/g" \
        -e "s/os_fqdn/$os_fqdn/" \
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
          -e '/## dev site/,/## dev site/d' \
          -e '/## live site/d' \
        /etc/nginx/sites-available/$fqdn"
      cmd_check
    elif [ "$i" == "dev" ]; then
      # e1: kill default_server; ec2: kill live site block; e3: kill header
      ssh $ssh_alias " \
        sudo sed -i \
          -e '/listen/ s/ default_server//' \
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
    \b\b\b\brestarting service... "
  ssh $ssh_alias "sudo nginx -t && sudo service nginx restart"
  cmd_check

  echo -e "\n$yellow \bNginx HTTP server logs are located at: \n$blue \
    \n/var/log/nginx/access.log \
    \n/var/log/nginx/error.log"

  echo -e "\n$yellow \bAccess your new websites at: \n$blue \
    \nLive:\t$os_fqdn_title \
    \nAlias:\twww.$os_fqdn_title \n \
    \nDev:\t$os_fqdn_dev_title \
    \nAlias:\twww.$os_fqdn_dev_title"

  echo -e "\n$green \bOpening live website... $reset"
  ec2_eip_fetch silent && open http://$ec2_ip_last
} # end func: os_nginx_config
