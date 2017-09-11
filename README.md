```
     ___    ____  _____  ____
    / _ \  / __ \|  ___||  _  \
   / /_\ \| /  \/| |__  | | | |
   |  _  || |    |  __| | | | |
   | | | || \__/\| |___ | |/ /
   \_| |_/ \____/\____/ |___/

   ACED: AWS Cloud Easy Deploy

```
ACED is a highly opinionated, yet user configurable, EC2 instance generator. ACED automates the provisioning of a secure and lightweight cloud environment, allows for fast teardowns/rebuilds, and provides canned CLI monitoring and admin tools. ACED is comprised of a series of bash scripts utilizing AWS API calls to configure AWS IAM service (access keys, groups, inline policies, users), AWS EC2 service (key pair, security groups, ingress/egress rules, instance launch, Elastic IP address), hardened Ubuntu Server and tuned Nginx HTTP server. As configured, ACED provides a solid platform to serve websites built by static site generators, such as [Hugo](https://gohugo.io), [Hexo](https://hexo.io) and [Jekyll](https://jekyllrb.com). Since ACED is comprised of bash scripts, it can be expanding upon to install the run-time and/or server scripting of your choice to serve dynamic websites and/or web apps.

To read more, see my blog post at [www.DevOpsEtc.com](https://www.DevOpsEtc.com/post/aced-aws-cloud-easy-deploy/)

**Road Map:**
- Rotate AWS IAM access_keys
- Rotate EC2 public/private key
- Refactor uninstall
- Install MTA (fail2ban notifications)
- Add IP6Tables rules
- Implement port knocking
- Install openVPN
- S3 Bucket for images
- create custom Debian ami

**PRs welcome, or just fork it (YMMV!)**
