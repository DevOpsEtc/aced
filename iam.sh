#!/usr/bin/env bash

####################################################
##  filename:   iam.sh                            ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    IAM group, policy, user           ##
##  date:       03/08/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

iam() {
  iam_root_keys
  iam_group
  iam_user
  iam_user_keys
  iam_root_keys_rm
  aws_config
}

iam_rotate_keys() {
  iam_user_keys
  aws_config
}

iam_root_keys() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Create Temporary Root Access Keys  XX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  echo -e "$green
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
  echo -e "\n$green \bCopy/paste AWS access keys (enter nothing for default \
  \b\bregion & output) \n$yellow"
  aws configure
  return_check

} # end function: iam_root_keys

iam_group() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Check Existing IAM Group  XXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with group names
  get_group=($(aws iam list-groups \
    --query Groups[*].GroupName \
    --output text)
  )

  if [ ${#get_group[@]} -ne 0 ]; then
    echo -e "\n$yellow \bFound IAM group(s): "
    echo $blue; printf '%s\n' "${get_group[@]}"
    echo $yellow; read -rp "Delete all IAM group(s)? [Y/N] " response
    echo

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      # loop through list of group names
      for g in "${get_group[@]}"; do
        # populate array with a group's usernames
        get_group_user=($(aws iam get-group \
          --group-name "$g" \
          --query Users[*].UserName \
          --output text)
        )

        # do if group has user
        if [ ${#get_group_user[@]} -ne 0 ]; then
          # loop through list of usernames
          for u in "${get_group_user[@]}"; do
            echo -e "$green \bRemoving user: $u from group: $g..."
            aws iam remove-user-from-group --user-name "$u" --group-name "$g"
          done
        fi

        # populate array with a group's policy names
        get_group_pol=($(aws iam list-group-policies \
          --group-name "$g" \
          --query PolicyNames[*] \
          --output text)
        )

        # do if group has policy
        if [ ${#get_group_pol[@]} -ne 0 ]; then
          # loop through list of policy names
          for p in "${get_group_pol[@]}"; do
            echo -e "$green \bRemoving policy: $p from group: $g..."
            aws iam delete-group-policy --group-name "$g" --policy-name "$p"
          done
        fi

        echo -e "$green \bDeleting IAM group: $g..."
        aws iam delete-group --group-name "$g"
        return_check
      done

      unset get_group
    else
      echo -e "\n$green \bKeeping IAM group(s)!"
    fi
  else
    echo -e "\n$yellow \bNo AWS IAM group found!"
  fi

  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Create New IAM Group  XXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  unset iam_group_name iam_group # delete group vars

  while [ "$iam_group_name" != "valid" ] ; do
    echo $yellow
    read -rp "Enter name for new AWS IAM group, e.g. name_group: " \
      iam_group

    # check for existing IAM group name; kick back to while loop if found
    if echo "${get_group[@]}" | grep -q -w "$iam_group"; then
      echo -e "\n$red \bAWS IAM group already exists: $iam_group"
    else
      iam_group_name=valid
    fi
  done

  echo -e "\n$green \bCreating $iam_group..."
  echo $blue; aws iam create-group --group-name $iam_group
  return_check  #

  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Create Embedded Inline IAM Policy  XX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # online generator: https://awspolicygen.s3.amazonaws.com/policygen.html

  echo $yellow
  read -rp "Enter name for new IAM policy, e.g. name_policy: " iam_policy

  echo -e "\n$green \bEmbedding policy: $iam_policy to group: \
  \b\bXX\b$iam_group... $blue"
  aws iam put-group-policy \
    --group-name $iam_group \
    --policy-name $iam_policy \
    --policy-document \
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
            "Resource": "arn:aws:ec2:*:account:instance/*",
            "Condition": {
              "StringNotEquals": {
                "ec2:Region": "us-west-1",
                "ec2:InstanceType": "t2.micro"
              }
            }
          }
        ]
      }
    '
    return_check

  # invoke function to update placeholder values of passed args in AED config
  update_config iam_group iam_policy
}

iam_user() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Check Existing IAM User  XXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with usernames
  get_user=($(aws iam list-users \
    --query Users[*].UserName \
    --output text)
  )

  # check for IAM user; print names; prompt to delete
  if [ ${#get_user[@]} -ne 0 ]; then
    echo -e "\n$yellow \bFound existing IAM user:"
    echo $blue; printf '%s\n' "${get_user[@]}"

    echo $yellow; read -rp "Delete IAM user(s)? [Y/N] " response

    # check for response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      # loop through array of IAM users
      for i in "${get_user[@]}"; do
        # populate array with a user's access key IDs
        get_user_keys=($(aws iam list-access-keys \
          --user-name "$i" \
          --query AccessKeyMetadata[*].AccessKeyId \
          --output text)
        )

        # do if user has access key
        if [ ${#get_user_keys[@]} -ne 0 ]; then
          # loop through list of access key IDs
          for k in "${get_user_keys[@]}"; do
            echo -e "\n$green \bRemoving access key for user: $i..."
            aws iam delete-access-key --access-key $k --user-name "$i"
          done
        fi

        echo -e "$green \bDeleting IAM user: $i..."
        aws iam delete-user --user-name "$i"
        return_check

        # delete array
        unset get_user
      done
    else
      echo -e "\n$green \bKeeping IAM user(s)!"
    fi
  else
    echo -e "\n$yellow \b No AWS IAM user found! $rs"
  fi

  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Create New IAM User  XXXXXXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  unset iam_username iam_user

  while [ "$iam_username" != "valid" ] ; do
    echo $yellow;
    read -rp "Enter name for new IAM user, e.g name_admin: " iam_user

    # check for existing IAM username; kick back to while loop if found
    if echo "${get_user[@]}" | grep -q -w "$iam_user"; then
      echo -e "\n$red \bAWS IAM username already exists: $iam_user $rs"
    else
      iam_username=valid
    fi
  done

  echo -e "\n$green \bCreating $iam_user... \n$blue"
  aws iam create-user --user-name $iam_user
  return_check

  echo -e "\n$green \bAdding IAM user: $iam_user to $iam_group..."
  aws iam add-user-to-group --user-name $iam_user --group-name $iam_group
  return_check

  # invoke function to update placeholder values of passed args in AED config
  update_config iam_user
}

iam_user_keys() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Create IAM User Access Keys  XXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # create IAM user access key; redirect awk output to file
  echo -e "\n$green \bCreating an access key for IAM user: $iam_user..."
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
  echo "output = $api_output" >> $aed_aws/config
  echo "region = $api_region" >> $aed_aws/config
}

iam_root_keys_rm() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Delete Root Access Keys  XXXXXXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # populate array with a root's access key IDs
  get_root_keys=($(aws iam list-access-keys \
    --query AccessKeyMetadata[*].AccessKeyId \
    --output text)
  )

  # do if root has access key
  if [ ${#get_root_keys[@]} -ne 0 ]; then
    # loop through list of access key IDs
    for k in "${get_root_keys[@]}"; do
      echo -e "\n$green \bRemoving access key ID: $k from root..."
      aws iam delete-access-key --access-key $k
      return_check
    done
  fi
}

aws_config() {
  echo -e "$white
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  \b\bXX  Localhost AWS Configuration  XXXXXXXX
  \b\bXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

  # backup any existing AWS config
  if [ -d $aws_config ]; then
    mv -f $aws_config/* $aed_aws &>/dev/null
    echo -e "\n$yellow \bExisting AWS dotfiles found and saved to: "
    echo $blue; find $aed_aws
  fi

  # overwrite localhost AWS credentials file
  echo -e "\n$green \bUpdating AWS credentials for: $iam_user...\n $blue"
  mv -f $aed_aws/credentials_tmp $aed_aws/credentials
  return_check

  # symlink AWS config & credentials files to default location
  echo -e "\n$green \bCreating AWS dotfile symlinks... \n$blue"
  ln -sf $aws_cfg $aws_config && ln -sf $aws_crd $aws_config
  return_check
}
