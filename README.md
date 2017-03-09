```
  ┏━━━━━━━━━━━━━━━┓
  ┃      _    _____ ____    ┃
  ┃     / \  | ____|  _ \   ┃
  ┃    / _ \ |  _| | | | |  ┃
  ┃   / ___ \| |___| |_| |  ┃
  ┃  /_/   \_\_____|____/   ┃
  ┃                         ┃
  ┗━━━ AWS EC2 Deploy━━━┛
```

**What is AED:** <br>
AED is an Amazon Web Services EC2 instance generator. Highly opinionated and user configurable, AED automates AWS API calls via the aws-cli app to create a fast, secure & lightweight server running the Ghost publishing platform.

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

**Why Use AED:** <br>
Wicked fast deployment of a web server/blog on the cheap. Just how fast? Launch instance, harden server, install/config apps and push to remote repo quicker than you can drink a grande skinny latte! Just how cheap? FREE for a year, can't beat that!

Designed for lazy people by a lazy person. Don't build your web server by hand anymore, and stop using the AWS Management Console for every darn EC2 task.

**Prerequisites:** <br>
- Register for free AWS account: <br>
    https://aws.amazon.com/free

- Install aws-cli for AWS API access: <br>
    http://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html

- Have existing or generate a new public-key encryption key pair: <br>
    https://github.com/DevOpsEtc/bin/blob/master/key_pair.sh

**Installing AED:** <br>
1. Clone deploy repo <br>
`$ git clone https://github.com/DevOpsEtc/aed ~/aed/app`

2. Run AED app <br>
`$ ~/aed/app/aed.sh`

**Getting Started:** <br>

AED Commands:
```
$ aed                    # AED: task menu
$ aed -c or -connect     # EC2: remote access connect
$ aed -ip                # EIP: rotate public IP
$ aed -on or -start      # EC2: instance start
$ aed -off or -stop      # EC2: instance stop
$ aed -r or -rule        # EC2: remote access ingress rules
$ aed -rb or -reboot     # EC2: instance reboot
$ aed -s or -status      # EC2: instance status
$ aed -sec or -security  # EC2: keys, group, & rule tasks
$ aed -u or -uninstall   # AED: uninstall
$ aed -v or -version     # AED: version information
$ aed -? or -h or -help  # AED: help
```

**Remote Access:** <br>
AED generates an EC2 ingress rule which restricts remote access to SSH connections originating from the public IP address in use during install. You can easily create/revoke new ingress rules for access from anywhere by running:

`$ aed -rule.`

**Git Repository:** <br>
AED generated a remote git repo, which you can connect to push blog posts to Ghost. To get started, you need to create a new local git repo.

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
