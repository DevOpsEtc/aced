#!/usr/bin/env bash

####################################################
##  filename:   iam.sh                            ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    IAM group, policy, user           ##
##  date:       03/10/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

iam() {
  iam_keys_root
  iam_group_create
  iam_policy_create
  iam_user_create
  iam_keys_create
  iam_keys_root_rm
  aws_config
}

iam_keys_rotate() {
  iam_keys_create
  aws_config
}

iam_keys_root() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  IAM: Create Temporary Root Access Keys  XX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # backup any existing AWS config
  if [ -d $aws_config ]; then
    mv -f $aws_config/* $aed_aws/old &>/dev/null
    echo -e "\n$yellow \bExisting AWS dotfiles found and saved to: "
    echo $blue; find $aed_aws
  fi

  echo -e "$gray
  1. Open https://console.aws.amazon.com/iam/home#/security_credential
  2. Sign in to your account if prompted
  3. Click \"Continue to Security Credentials\" if message modal appears
  4. Expand \"Access Keys (Access Key ID and Secret Access Key)\"
  5. Delete an access key if needed (only two allowed)
  6. Click button \"Create New Access Key\"
  7. Expand \"Show Access Key\" in modal"

  # wait 5 seconds before opening website in browser
  sleep 3 && open https://console.aws.amazon.com/iam/home#/security_credential

  # configure aws-cli with credentials
  echo -e "\n$gray \bCopy/paste AWS access keys (enter nothing for default \
  \b\bregion & output) \n$yellow"
  aws configure
  return_check
  return
} # end function: iam_keys_root

iam_group_create() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  IAM: Group Creation  XXXXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bChecking for existing IAM group: $iam_group..."
  fetch_groups=$(aws iam list-groups --query Groups[*].GroupName --output text)

  if echo $fetch_groups | grep -q -w "$iam_group" ; then
    echo -e "\n$yellow \b$iam_group found!"

    echo -e "\n$green \bFetching $iam_group's member list..."
    fetch_group_users=($(aws iam get-group \
      --group-name "$iam_group" \
      --query Users[*].UserName \
      --output text)
    )

    # remove any users from membership
    if [ ${#fetch_group_users[@]} -gt 0 ]; then
      for u in "${fetch_group_users[@]}"; do
        echo -e "\n$green \bRemoving user: $u..."
        aws iam remove-user-from-group --user-name $u --group-name "$iam_group"
        return_check
      done
    else
      echo -e "\n$yellow \bNo members found!"
    fi

    echo -e "\n$green \bFetching $iam_group's policy list..."
    fetch_group_pols=($(aws iam list-group-policies \
      --group-name "$iam_group" \
      --query PolicyNames[*] \
      --output text)
    )

    # remove any group policies
    if [ ${#fetch_group_pols[@]} -gt 0 ]; then
      for p in "${fetch_group_pols[@]}"; do
        echo -e "\n$green \bRemoving policy: $p..."
        aws iam delete-group-policy \
          --group-name "$iam_group" \
          --policy-name "$p"
        return_check
      done
    else
      echo -e "\n$yellow \bNo policies found!"
    fi

    echo -e "\n$green \bDeleting IAM group: $iam_group..."
    aws iam delete-group --group-name "$iam_group"
    return_check
  else
    echo -e "\n$yellow \bIAM group: $iam_group not found!"
  fi

  echo -e "\n$green \bCreating IAM user group: $iam_group..."
  echo $blue; aws iam create-group --group-name $iam_group
  return_check
}

iam_policy_create() {
  # policy generator: https://awspolicygen.s3.amazonaws.com/policygen.html
  # ARNs: http://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  IAM: Policy Creation  XXXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # fetch AWS account ID
  aws_account=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[0].OwnerId' \
    --output text
    )

  echo -e "\n$green \bEmbedding IAM inline policy $iam_pol_iam..."
  aws iam put-group-policy \
    --group-name $iam_group \
    --policy-name $iam_pol_iam \
    --policy-document  \
    '{
      "Version": "2012-10-17",
      "Statement": {
        "Sid": "AllowUserToSeeAndManageOwnAccessKeys",
        "Effect": "Allow",
        "Action": ["iam:*AccessKey*"],
        "Resource": "arn:aws:iam::'$aws_account':user/${aws:username}"
      }
    }'
  return_check

  echo -e "\n$green \bEmbedding IAM inline policy $iam_pol_ec2..."
  aws iam put-group-policy \
    --group-name $iam_group \
    --policy-name $iam_pol_ec2 \
    --policy-document  \
    '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "AllowAllEC2Actions",
          "Action": "ec2:*",
          "Effect": "Allow",
          "Resource": "*"
        },
        {
          "Sid": "DenyRunInstanceIfNotProperRegionAndType",
          "Action": [
            "ec2:RunInstances"
          ],
          "Effect": "Deny",
          "Resource": "arn:aws:ec2:*:'$aws_account':instance/*",
          "Condition": {
            "StringNotEquals": {
              "ec2:Region": "us-west-1",
              "ec2:InstanceType": "t2.micro"
            }
          }
        }
      ]
    }'
  return_check
}

iam_user_create() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  IAM: User Creation  XXXXXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "\n$green \bChecking for existing IAM user: $iam_user..."
  fetch_users=$(aws iam list-users --query Users[*].UserName --output text)

  if echo $fetch_users | grep -q -w "$iam_user"; then
    echo -e "\n$yellow \b$iam_user found!"

    echo -e "\n$green \bFetching $iam_user's group membership..."
    fetch_groups=($(aws iam list-groups-for-user \
      --user-name $iam_user \
      --query Groups[*].GroupName \
      --output text)
    )

    # remove user from any group membership
    if [ ${#fetch_groups[@]} -gt 0 ]; then
      for g in "${fetch_groups[@]}"; do
        echo -e "\n$green \bRemoving from group: $g..."
        aws iam remove-user-from-group --user-name $iam_user --group-name "$g"
        return_check
      done
    else
      echo -e "\n$yellow \bNo group membership for $iam_user!"
    fi

    iam_keys_remove # invoke function to check/remove $iam_user access keys

    echo -e "\n$green \bDeleting IAM user: $iam_user..."
    aws iam delete-user --user-name "$iam_user"
    return_check
  else
    echo -e "\n$yellow \b$iam_user not found!"
  fi

  echo -e "\n$green \bCreating $iam_user... \n$blue"
  aws iam create-user --user-name $iam_user
  return_check

  echo -e "\n$green \bAdding $iam_user to group: $iam_group..."
  aws iam add-user-to-group --user-name $iam_user --group-name $iam_group
  return_check
}

iam_keys_remove() {
  echo -e "\n$green \bChecking $iam_user's access keys..."
  user_access_keys=($(aws iam list-access-keys \
    --user-name "$iam_user" \
    --query AccessKeyMetadata[*].AccessKeyId \
    --output text)
  )

  # remove any user access keys
  if [ ${#user_access_keys[@]} -gt 0 ]; then
    for k in "${user_access_keys[@]}"; do
      echo -e "\n$green \bDeleting $iam_user's access key $k..."
      aws iam delete-access-key --access-key $k --user-name "$iam_user"
      return_check
    done
  else
    echo -e "\n$yellow \bNo access keys found for $iam_user..."
  fi
}

iam_keys_create() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  IAM: User Access Key Creation  XXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  iam_keys_remove # invoke function to check/remove $iam_user access keys

  # create IAM user access key; redirect awk output to file
  echo -e "\n$green \bCreating access keys for: $iam_user..."
  aws iam create-access-key --user-name $iam_user \
    | awk '/AccessKeyId/ || /SecretAccessKey/ { \
    gsub(/"/, ""); \
    gsub(/,/, ""); \
    gsub(/:/, "="); \
    gsub(/AccessKeyId/, "aws_access_key_id ", $1); \
    gsub(/SecretAccessKey/, "aws_secret_access_key ", $1); \
    print $1,$2}' > $aed_aws/credentials_tmp
  return_check

  # insert profile name to top of temp AWS credentials file
  sed -i '' '1i\
    [default]\
    ' $aed_aws/credentials_tmp

  # delete AWS config file, recreate, change permissions & insert values
  echo -e "\n$green \bCreating Localhost AWS configuration..."
  if [ -f $aed_aws/config ]; then
    rm -f $aed_aws/config &>/dev/null
  fi
  touch $aed_aws/config
  chmod =,u+rw $aed_aws/config
  echo "[default]" >> $aed_aws/config
  echo "output = $aws_output" >> $aed_aws/config
  echo "region = $aws_region" >> $aed_aws/config
  return_check
}

iam_keys_root_rm() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  IAM: Remove Root Access Keys  XXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with a root's access key IDs
  fetch_root_keys=($(aws iam list-access-keys \
    --query AccessKeyMetadata[*].AccessKeyId \
    --output text)
  )

  # remove any access keys
  if [ ${#fetch_root_keys[@]} -ne 0 ]; then
    for k in "${fetch_root_keys[@]}"; do
      echo -e "\n$green \bDeleting root access key ID: $k..."
      aws iam delete-access-key --access-key $k
      return_check
    done
  fi
}

aws_config() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  IAM: Localhost AWS Configuration  XXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # overwrite localhost AWS credentials file
  echo -e "\n$green \bUpdating AWS credentials for: $iam_user..."
  mv -f $aed_aws/credentials_tmp $aed_aws/credentials
  return_check

  # symlink AWS config & credentials files to default location
  echo -e "\n$green \bCreating AWS dotfile symlinks..."
  ln -sf $aed_aws/config $aws_config && ln -sf $aed_aws/credentials $aws_config
  return_check
}
