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
  1. clone deploy repo <br>
  `$ git clone https://github.com/DevOpsEtc/aed ~/aed/app`

  2. source AED app <br>
  `$ . ~/aed/app/aed.sh`

  3. permanently source AED app for new shells <br>
  # append to bash_profile or bashrc

  # OPTIONAL

  # create a new local git repo to store blog posts (markdown files)

  # add a git remote
  $ git remote add origin [domainName.com/path/to/repo]

  # verify new remote URL
  $ git remote -v               

  # push changes in local repo up to new remote repo; -u sets upstream, to
  # omit remote & branch names when running git pull/push
  $ git push -u origin master
  ```

**Getting Started:** <br>

AED Command Options:
```
$ aed -ip or -eip         # allocate|associate|release Elastic IP
$ aed -on or -start       # start EC2 instance
$ aed -off or -stop       # stop EC2 instance
$ aed -r or -rule         # add|remove temporary remote access rule
$ aed -rb or -reboot      # reboot EC2 instance
$ aed -rs or -reset       # delete AED env vars; invoke install
$ aed -sg or -sec         # import|add|delete EC2 keys/groups/rules
$ aed -ssh or -connect    # connect to remote EC2 server cli
$ aed -st or -status      # list EC2 instance status
$ aed -t or -terminate    # delete EC2 instance
$ aed -u or -uninstall    # AED uninstall
$ aed -v or -version      # AED release version information
$ aed -? or -h or -help   # AED command options listing
```

**Optional:**
  ```
  # append to $PATH to allow running by filename only
  $ export PATH="$deployPath:$PATH"

  # remove repo directory:
  $ rm -rf $deployPath/.git

  # make permanent by adding to end of existing .bash_profile:
  $ echo "export PATH="$deployPath:$PATH"" >> .bash_profile

  # create bash alias:
  $ echo "alias color='$deployPath/term_colors.sh'" >> .bash_profile
  ```

**Notes:** <br>
- Scripts were coded for Mac OSX, but will work with Linux with minor mods to command flags
- Windows could work if bash and other commands are installed and file paths are adjusted accordingly
- Scripts written against aws-cli version 1.11.48 commands
- Extend AED with other aws-cli scripts; see the examples folder after installation:

```
# store path to aws examples
$ awsExamples=/usr/local/share/awscli/examples

# change directory & list contents
$ cd $awsExamples/ec2 && ls

# display example content
$ cat revoke-security-group-ingress.rst
```

**Roadmap:**

- Write Uninstaller Script
- Install/Config Apps:
	-  ZNC (IRC bouncer)
	-  Self-Hosted VPN
      - OpenVPN
	-  Self-Hosted Mail:
      - PostFix
      - DoveCot
      - SpamAssin

**PRs welcome, or fork it (YMMV!)**
