```
     ___   _____  _____ ______
    / _ \ /  __ \|  ___||  _  \
   / /_\ \| /  \/| |__  | | | |
   |  _  || |    |  __| | | | |
   | | | || \__/\| |___ | |/ /
   \_| |_/ \____/\____/ |___/

 AWS Cloud Environment Deployment

```

**What is ACED:** <br>
ACED is an Amazon Web Services EC2 instance generator. Highly opinionated and user configurable, ACED automates AWS API calls via the aws-cli app to create a fast, secure & lightweight server running the Ghost publishing platform.

- Single EC2 Instance with EBS volume
- Elastic IP for custom domain name
- S3 storage
- Hardened Ubuntu Server 16.04 LTS
- Non-root user with remote access over VPN
- Automatic security updating

Apps installed & configured:

- iptables
- fail2ban
- openSSH
- NGINX
- Node.js
- Express.js
- postgreSQL
- Ghost
- Git
- OpenVPN

**Why Use ACED:** <br>
Wicked fast deployment of a HTTP server/blog on the cheap. Just how fast? Launch instance, harden server, install/config apps and push to remote repo quicker than you can drink a grande skinny latte! Just how cheap? FREE for a year, can't beat that!

Designed for lazy people by a lazy person. Don't build your HTTP server by hand anymore, and stop using the AWS Management Console for every darn EC2 task.

**Prerequisites:** <br>
- Register for free AWS account: <br>
    https://aws.amazon.com/free

- Install aws-cli for AWS API access: <br>
    http://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html

- Have existing or generate a new public-key encryption key pair: <br>
    https://github.com/DevOpsEtc/bin/blob/master/key_pair.sh

**Installing ACED:** <br>
1. Clone deploy repo <br>
`$ git clone https://github.com/DevOpsEtc/aced ~/aced/app`

2. Run ACED app <br>
`$ ~/aced/app/aced.sh`

**Getting Started:** <br>

ACED Commands:
```
$ aced                    # show ACED task menu
$ aced -c or -connect     # access ACED instance via SSH
$ aced -ip                # show ACED public IP address
$ aced -on or -start      # start ACED instance
$ aced -off or -stop      # stop ACED instance
$ aced -r or -rule        # add ingress rule for remote access to ACED
$ aced -rb or -reboot     # reboot ACED instance
$ aced -s or -status      # show ACED instance status
$ aced -u or -uninstall   # uninstall ACED
$ aced -v or -version     # show ACED version information
$ aced -? or -h or -help  # show ACED help
```

**Remote Access:** <br>
ACED generates an EC2 ingress rule which restricts remote access to SSH connections originating from the public IP address in use during install. You can easily create/revoke new ingress rules for access from anywhere by running:

`$ aced -rule.`

**Git Repository:** <br>
ACED generated a remote git repo, which you can connect to push blog posts to Ghost. To get started, you need to create a new local git repo.

```
# remove repo directory:
$ rm -rf $deployPath/.git

# create a new local git repo to store blog posts (markdown files)

# add a git remote
$ git remote add origin [domainName.com/path/to/repo]

# verify new remote URL
$ git remote -v               

# push changes in local repo up to new remote repo; -u sets upstream, to
# omit remote & branch names when running git pull/push
$ git push -u origin master
```

**Notes:** <br>
- Scripts were coded for Mac OSX, but will work with Linux with minor mods to some command flags
- Windows could work if bash and other commands are installed and file paths are adjusted accordingly
- Scripts written against aws-cli version 1.11.48 commands

**Roadmap:** <br>
- Write Uninstaller Script
- Install/Config Apps:
	-  ZNC (IRC bouncer)
	-  Self-Hosted VPN
      - OpenVPN
	-  Self-Hosted Mail:
      - PostFix
      - DoveCot
      - SpamAssin
- Refactor using Python: https://aws.amazon.com/sdk-for-python/

**PRs welcome, or fork it (YMMV!)**
