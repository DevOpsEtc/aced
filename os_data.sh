#!/usr/bin/env bash

#####################################################
##  filename:   os_data.sh                         ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    deployment tasks                   ##
##  date:       04/24/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

os_data() {
  echo -e "\n$white \b****  OS: Data Tasks  ****"

  os_file  # invoke func: create file structure for deployment
  # os_repo  #
}

os_file() {
  echo -e "\n$green \bRemote: creating file structure for static website... "
  echo $blue; ssh $ssh_alias " \
    sudo mkdir -p /var/www/$os_fqdn/{dev,live} \
    && sudo rm -rf /var/www/html"
  cmd_check

  echo -e '
  <style> h1 { text-align: center; color: red; } </style>
  <h1>Welcome to '"$aced_nm"'!</h1>' \
    | ssh $ssh_alias " \
      sudo tee $os_www_live/index.html > /dev/null"
  cmd_check

  ec2_eip_fetch silent
  open http://$ec2_ip_last

  # echo -e "\n$green \bRemote: changing ownership: /var/www/$os_fqdn => \
  #   $os_nginx_user... "
  # ssh $ssh_alias "sudo chown -R \$USER:$os_nginx_user /var/www/$os_fqdn"
  # cmd_check

  # echo -e "\n$green \bRemote: changing file permissions: /var/www/$os_fqdn => \
  #   \b\b\b\b755"
  # ssh $ssh_alias "sudo chmod -R u=rwx,go=rx /var/www/$os_fqdn"
  #
  # echo -e "\n$green \bRemote: creating file structure for repos... "
  # ssh $ssh_alias "mkdir -p $os_src_blog/{dev,live}/repo.git"
  # cmd_check
  # echo $blue; ssh $ssh_alias "tree"
}

os_repo() {
  repo_names=("dev" "live")

  for i in "${repo_names[@]}"; do
    echo -e "\n$green \bRemote: creating post-receive hook: blog-$i... "
    echo -e "#"'!'"/bin/bash \ngit --work-tree=/var/www/$os_fqdn/$i/html \
      --git-dir=$os_src_blog/$i/repo.git checkout -f" \
      | ssh $ssh_alias "tee $os_src_blog/$i/repo.git/hooks/post-receive > \
      /dev/null"
    cmd_check

    echo -e "\n$green \bRemote: setting permissions: +x post-receive... "
    ssh $ssh_alias "chmod +x $os_src_blog/$i/repo.git/hooks/post-receive"
    cmd_check

    if [ $i == "live" ]; then
      [[ -d $aced_blog ]] && rm -rf $aced_blog/*

      echo -e "\n$green \bRemote: creating bare git repo for blog-$i... "
      echo $blue; ssh $ssh_alias "cd $os_src_blog/$i/repo.git \
        && git init --bare"
      cmd_check

      echo -e "\n$green \bLocalhost: creating git repo for blog-$i... "
      echo $blue; git -C $aced_blog init
      cmd_check

      echo -e "\n$green \bLocalhost: adding remote repo for blog-$i... "
      git -C $aced_blog remote add blog-$i \
        ssh://$os_user@$ec2_ip:$os_ssh_port$os_src_blog/$i/repo.git
      cmd_check

      echo -e "\n$green \bLocalhost: populating test page for blog-$i... "
      echo "<h1>Aced Website Ready... Enjoy"'!'"</h1>" \
        > $aced_blog/index.html
      cmd_check

      echo -e "\n$green \bLocalhost: git adding/commiting/pushing content... "
      git -C $aced_blog add . \
        && git -C $aced_blog commit -m "initial commit" \
        && git -C $aced_blog push -u blog-$i master
      cmd_check

      echo -e "\n$white \bOpening website in 2 seconds... \n$yellow"
      sleep 2
      open http://$ec2_ip_last
    fi
  done
}
