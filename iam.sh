#!/usr/bin/env bash

####################################################
##  filename:   iam.sh                            ##
##  path:       ~/src/deploy/cloud/aws/           ##
##  purpose:    IAM group, policy, user           ##
##  date:       03/02/2017                        ##
##  repo:       https://github.com/DevOpsEtc/aed  ##
##  clone path: ~/aed/app/                        ##
####################################################

# invoke all functions in script
aed_iam() {
  aed_iam_root_keys
  aed_iam_group
  aed_iam_user
  aed_iam_user_keys
}

aed_iam_root_keys() {
  echo -e "$aed_grn
  \b\b######################################################
  \b\b##  Create Temporary AWS Root Access Keys  ###########
  \b\b######################################################"

  echo -e "$aed_ylw
  1. Open https://console.aws.amazon.com/iam/home#/security_credential
  2. Sign in to your account if prompted
  3. Click "Continue to Security Credentials" if message modal appears
  4. Expand \"Access Keys (Access Key ID and Secret Access Key)\"
  5. Delete an access key if needed (only two allowed)
  6. Click button \"Create New Access Key\"
  7. Expand \"Show Access Key\" in modal"

  # wait 5 seconds before opening website in browser
  sleep 5 && open https://console.aws.amazon.com/iam/home#/security_credential

  echo -e "$aed_grn
  \b\b######################################################
  \b\b##  Check Existing Localhost AWS Configuration  ######
  \b\b######################################################"

  # check for existing AWS config; backup if found; list files
  if [ -d $aed_aws_dotfile ]; then
    echo -e "\n$aed_ylw \bLocalhost AWS configuration found: "
    echo $aed_blu; find $aed_aws_dotfile -type f -maxdepth 1

    mv -f $aed_aws_dotfile $aed_aws_dotfile_bk &>/dev/null

    echo -e "\n$aed_ylw \bLocalhost AWS configuration saved to: "
    echo $aed_blu; find $aed_aws_dotfile_bk -type f -maxdepth 1
  else
    echo -e "\n$aed_ylw \bLocalhost AWS configuration not found! "
  fi

  # configure aws-cli with credentials
  echo -e "\n$aed_grn \bCopy/paste AWS access keys (enter nothing for default \
  \b\bregion/output) \n$aed_ylw"
  aws configure
}

aed_iam_group() {
  echo -e "$aed_grn
  \b\b######################################################
  \b\b##  Check Existing AWS IAM Group  ####################
  \b\b######################################################"

  # populate array with group names
  aed_get_group=($(aws iam list-groups \
    --query Groups[*].GroupName \
    --output text)
  )

  # check for IAM groups; print names; prompt to delete
  if [ ${#aed_get_group[@]} -ne 0 ]; then
    echo -e "\n$aed_blu \bFound existing IAM group(s): "
    echo $aed_blu; printf '%s\n' "${aed_get_group[@]}"
    echo $aed_ylw; read -p "Delete existing IAM group(s)? [Y/N] " aed_opt

    # check for response
    if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      # loop through list of groups names
      for g in "${aed_get_group[@]}"; do
        # populate array with a group's usernames
        aed_get_group_user=($(aws iam get-group \
          --group-name "$g" \
          --query Users[*].UserName \
          --output text)
        )

        # do if group has user
        if [ ${#aed_get_group_user[@]} -ne 0 ]; then
          # loop through list of usernames
          for u in "${aed_get_group_user[@]}"; do
            echo -e "\n$aed_grn \bRemoving user: $u from group: $g..."
            aws iam remove-user-from-group --user-name "$u" --group-name "$g"
          done
        fi

        # populate array with a group's policy names
        aed_get_group_pol=($(aws iam list-group-policies \
          --group-name "$g" \
          --query PolicyNames[*] \
          --output text)
        )

        # do if group has policy
        if [ ${#aed_get_group_pol[@]} -ne 0 ]; then
          # loop through list of policy names
          for p in "${aed_get_group_pol[@]}"; do
            echo -e "\n$aed_grn \bRemoving policy: $p from group: $g..."
            aws iam delete-group-policy --group-name "$g" --policy-name "$p"
          done
        fi

        # remove group
        echo -e "\n$aed_grn \bDeleting IAM group: $g..."
        aws iam delete-group --group-name "$g"

        # delete array
        unset aed_get_group
      done
    else
      echo -e "\n$aed_grn \bKeeping IAM group(s)!"
    fi
  else
    echo -e "\n$aed_ylw \bNo AWS IAM group found!"
  fi

  echo -e "$aed_grn
  \b\b######################################################
  \b\b##  Create New AWS IAM Group  ########################
  \b\b######################################################"

  # delete group vars
  unset aed_group_name_ok aed_group

  # do while new group name is invalid
  while [ ! "$aed_group_name_ok" ]; do
    # prompt for new group name
    echo $aed_ylw
    read -p "Enter name for new AWS IAM group, e.g. name_group: " aed_group

    # check for existing IAM group name; kick back to while loop if found
    # if $(aws iam list-groups | grep -q "$aed_group"); then
    if echo "${aed_get_group[@]}" | grep -q -w "$aed_group"; then
      echo -e "\n$aed_red \bAWS IAM group already exists: $aed_group"
    else
      aed_group_name_ok=true
    fi
  done

  echo -e "\n$aed_grn \bCreating IAM group: $aed_group..."
  echo $aed_blu; aws iam create-group --group-name $aed_group

  echo -e "$aed_grn
  \b\b#######################################################
  \b\b##  Create Embedded Inline Policy in IAM group  #######
  \b\b#######################################################"

  # online generator: https://awspolicygen.s3.amazonaws.com/policygen.html

  echo $aed_ylw
  read -p "Enter name for new IAM policy on: $aed_group, e.g. name_policy: " \
    aed_policy

  echo -e "\n$aed_grn \bEmbedding inline policy: $aed_policy to IAM group: \
  \b\b$aed_group... \n$aed_blu"
  aws iam put-group-policy \
    --group-name $aed_group \
    --policy-name $aed_policy \
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
  # confirm policy is attached to group
  aws iam list-group-policies --group-name $aed_group
}

aed_iam_user() {
  echo -e "$aed_grn
  \b\b######################################################
  \b\b##  Check Existing AWS IAM User  #####################
  \b\b######################################################"

  # populate array with usernames
  aed_get_user=($(aws iam list-users \
    --query Users[*].UserName \
    --output text)
  )

  # check for IAM user; print names; prompt to delete
  if [ ${#aed_get_user[@]} -ne 0 ]; then
    echo -e "\n$aed_ylw \bFound existing IAM user:"
    echo $aed_blu; printf '%s\n' "${aed_get_user[@]}"

    echo $aed_ylw; read -p "Delete IAM user(s)? [Y/N] " aed_opt

    # check for response
    if [[ "$aed_opt" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      # loop through array of IAM users
      for i in "${aed_get_user[@]}"; do
        # populate array with a user's access key IDs
        aed_get_user_keys=($(aws iam list-access-keys \
          --user-name "$i" \
          --query AccessKeyMetadata[*].AccessKeyId \
          --output text)
        )

        # do if user has access key
        if [ ${#aed_get_user_keys[@]} -ne 0 ]; then
          # loop through list of access key IDs
          for k in "${aed_get_user_keys[@]}"; do
            echo -e "\n$aed_grn \bRemoving access key ID: $k from user: $i..."
            aws iam delete-access-key --access-key $k --user-name "$i"
          done
        fi

        echo -e "\n$aed_grn \bDeleting IAM user: $i..."
        aws iam delete-user --user-name "$i"

        # delete array
        unset aed_get_user
      done
    else
      echo -e "\n$aed_grn \bKeeping IAM user(s)!"
    fi
  else
    echo -e "\n$aed_ylw \b No AWS IAM user found! $rs"
  fi

  echo -e "$aed_grn
  \b\b######################################################
  \b\b##  Create New AWS IAM User  #########################
  \b\b######################################################"

  # delete user vars
  unset aed_username_ok aed_user

  # do while new username is invalid
  while [ ! "$aed_username_ok" ] ; do
    # prompt for new IAM username
    echo $aed_ylw;
    read -p "Enter name for new IAM user, e.g name_ec2_admin: " aed_user

    # check for existing IAM username; kick back to while loop if found
    # if $(aws iam list-users | grep -q "$aed_user"); then
    if echo "${aed_get_user[@]}" | grep -q -w "$aed_user"; then
      echo -e "\n$aed_red \bAWS IAM username already exists: $aed_user $rs"
    else
      aed_username_ok=true
    fi
  done

  # create IAM user
  echo -e "\n$aed_grn \bCreating IAM user: $aed_user...\n$aed_blu"
  aws iam create-user --user-name $aed_user

  echo -e "\n$aed_grn \bAdding IAM user: $aed_user to IAM group: $aed_group..."
  aws iam add-user-to-group --user-name $aed_user --group-name $aed_group
}

aed_iam_user_keys() {
  echo -e "$aed_grn
  \b\b#######################################################
  \b\b##  Create IAM User Access Keys  ######################
  \b\b#######################################################"

  # create IAM user access key; redirect awk output to file
  echo -e "\n$aed_grn \bCreating an access key for IAM user: $aed_user..."
  aws iam create-access-key --user-name $aed_user \
    | awk '/AccessKeyId/ || /SecretAccessKey/ { \
    gsub(/"/, ""); \
    gsub(/,/, ""); \
    gsub(/:/, "="); \
    gsub(/AccessKeyId/, "aws_access_key_id ", $1); \
    gsub(/SecretAccessKey/, "aws_secret_access_key ", $1); \
    print $1,$2}' > $aed_aws_crd_tmp

  # insert profile name to top of temp AWS credentials file
  sed -i '' '1i\
    [default]\
    ' $aed_aws_crd_tmp

    # delete AWS config file, recreate, change permissions & insert values
    echo -e "\n$aed_grn \bCreating Localhost AWS configuration..."
    if [ -f $aed_aws_cfg ]; then
      rm -f $aed_aws_cfg &>/dev/null
    fi
    touch $aed_aws_cfg
    chmod =,u+rw $aed_aws_cfg
    echo "[default]" >> $aed_aws_cfg
    echo "output = json" >> $aed_aws_cfg
    echo "region = us-west-1" >> $aed_aws_cfg # us-east-1, us-east-2, us-west-2

  echo -e "$aed_grn
  \b\b#######################################################
  \b\b##  Delete Root Access Keys  ##########################
  \b\b#######################################################"

  # populate array with a root's access key IDs
  aed_get_root_keys=($(aws iam list-access-keys \
    --query AccessKeyMetadata[*].AccessKeyId \
    --output text)
  )

  # do if root has access key
  if [ ${#aed_get_root_keys[@]} -ne 0 ]; then
    # loop through list of access key IDs
    for k in "${aed_get_root_keys[@]}"; do
      echo -e "\n$aed_grn \bRemoving access key ID: $k from root..."
      aws iam delete-access-key --access-key $k
    done
  fi

  # overwrite localhost AWS credentials file
  echo -e "\n$aed_grn \bUpdating localhost AWS credentials for new IAM user: \
  \b\b$aed_user...\n$aed_blu"
  mv -f $aed_aws_crd_tmp $aed_aws_crd

  # symlink AWS config & credentials files to default location
  echo -e "\n$aed_grn \bCreating symlinks to AWS credentials in default \
  \b\blocation..."
  ln -sf $aed_aws_cfg $aed_aws_dotfile
  ln -sf $aed_aws_crd $aed_aws_dotfile
}
