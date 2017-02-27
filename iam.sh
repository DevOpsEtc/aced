#!/usr/bin/env bash

######################################################
##  filename:     iam.sh												    ##
##  path:         ~/src/deploy/cloud/aws/						##
##  purpose:      IAM group, policy, user           ##
##  date:         02/26/2017												##
##  repo:         https://github.com/DevOpsEtc/aed	##
##  clone path:   ~/aed/app/                        ##
######################################################

# invoke all functions in this script
aed_iamAll() {
  aed_iamRootKeys
  aed_iamGroup
  aed_iamUser
  aed_iamUserKeys
}

aed_iamRootKeys() {
  echo -e "$green
  \b\b######################################################
  \b\b##  Create Temporary AWS Root Access Keys  ###########
  \b\b######################################################"

  echo -e "$yellow
  1. Open https://console.aws.amazon.com/iam/home#/security_credential
  2. Sign in to your account if prompted
  3. Click "Continue to Security Credentials" if message modal appears
  4. Expand \"Access Keys (Access Key ID and Secret Access Key)\"
  5. Delete an access key if needed (only two allowed)
  6. Click button \"Create New Access Key\"
  7. Expand \"Show Access Key\" in modal"

  # wait 5 seconds before opening website in browser
  sleep 5 && open https://console.aws.amazon.com/iam/home#/security_credential

  echo -e "$green
  \b\b######################################################
  \b\b##  Check Existing Localhost AWS Configuration  ######
  \b\b######################################################"

  # check for existing AWS config; backup if found; list files
  if [ -d $AWS_DOTFILE ]; then
    echo -e "\n$yellow \bLocalhost AWS configuration found: "
    echo $blue; find $AWS_DOTFILE -type f -maxdepth 1

    mv -f $AWS_DOTFILE $AWS_DOTFILE_BK &>/dev/null

    echo -e "\n$yellow \bLocalhost AWS configuration saved to: "
    echo $blue; find $AWS_DOTFILE_BK -type f -maxdepth 1
  else
    echo -e "\n$yellow \bLocalhost AWS configuration not found! "
  fi

  # configure aws-cli with credentials
  echo -e "\n$green \bCopy/paste AWS access keys (enter nothing for default \
  \b\bregion/output) \n$yellow"
  aws configure
}

aed_iamGroup() {
  echo -e "$green
  \b\b######################################################
  \b\b##  Check Existing AWS IAM Group  ####################
  \b\b######################################################"

  # populate array with group names
  getGroup=($(aws iam list-groups \
    --query Groups[*].GroupName \
    --output text)
  )

  # check for IAM groups; print names; prompt to delete
  if [ ${#getGroup[@]} -ne 0 ]; then
    echo -e "\n$blue \bFound existing IAM group(s): "
    echo $blue; printf '%s\n' "${getGroup[@]}"
    echo $yellow; read -p "Delete existing IAM group(s)? [Y/N] " response

    # check for response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      # loop through list of groups names
      for g in "${getGroup[@]}"; do
        # populate array with a group's usernames
        getGroupUser=($(aws iam get-group \
          --group-name "$g" \
          --query Users[*].UserName \
          --output text)
        )

        # do if group has user
        if [ ${#getGroupUser[@]} -ne 0 ]; then
          # loop through list of usernames
          for u in "${getGroupUser[@]}"; do
            echo -e "\n$green \bRemoving user: $u from group: $g..."
            aws iam remove-user-from-group --user-name "$u" --group-name "$g"
          done
        fi

        # populate array with a group's policy names
        getGroupPolicy=($(aws iam list-group-policies \
          --group-name "$g" \
          --query PolicyNames[*] \
          --output text)
        )
        # | awk 'BEGIN {ORS=" "}; {print $2}'

        # do if group has policy
        if [ ${#getGroupPolicy[@]} -ne 0 ]; then
          # loop through list of policy names
          for p in "${getGroupPolicy[@]}"; do
            echo -e "\n$green \bRemoving policy: $p from group: $g..."
            aws iam delete-group-policy --group-name "$g" --policy-name "$p"
          done
        fi

        # remove group
        echo -e "\n$green \bDeleting IAM group: $g..."
        aws iam delete-group --group-name "$g"

        # delete array
        unset getGroup
      done
    else
      echo -e "\n$green \bKeeping IAM group(s)!"
    fi
  else
    echo -e "\n$yellow \bNo AWS IAM group found!"
  fi

  echo -e "$green
  \b\b######################################################
  \b\b##  Create New AWS IAM Group  ########################
  \b\b######################################################"

  # delete group vars
  unset groupNameValid AED_GROUP

  # do while new group name is invalid
  while [ "$groupNameValid" != true ]; do
    # prompt for new group name
    echo $yellow
    read -p "Enter name for new AWS IAM group, e.g. name_group: " AED_GROUP

    # check for existing IAM group name; kick back to while loop if found
    # if $(aws iam list-groups | grep -q "$AED_GROUP"); then
    if echo "${getGroup[@]}" | grep -q -w "$AED_GROUP"; then
      echo -e "\n$red \bAWS IAM group already exists: $AED_GROUP"
    else
      groupNameValid=true
    fi
  done

  echo -e "\n$green \bCreating IAM group: $AED_GROUP..."
  echo $blue; aws iam create-group --group-name $AED_GROUP

  echo -e "$green
  \b\b#######################################################
  \b\b##  Create Embedded Inline Policy in IAM group  #######
  \b\b#######################################################"

  # online generator: https://awspolicygen.s3.amazonaws.com/policygen.html

  echo $yellow
  read -p "Enter name for new IAM policy on: $AED_GROUP, e.g. name_policy: " \
  AED_POLICY

  echo -e "\n$green \bEmbedding inline policy: $AED_POLICY to IAM group: \
  \b\b$AED_GROUP... \n$blue"
  aws iam put-group-policy \
    --group-name $AED_GROUP \
    --policy-name $AED_POLICY \
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
  # confirm the policy is attached to group
  aws iam list-group-policies --group-name $AED_GROUP
}

aed_iamUser() {
  echo -e "$green
  \b\b######################################################
  \b\b##  Check Existing AWS IAM User  #####################
  \b\b######################################################"

  # populate array with usernames
  getUser=($(aws iam list-users \
    --query Users[*].UserName \
    --output text)
  )

  # check for IAM user; print names; prompt to delete
  if [ ${#getUser[@]} -ne 0 ]; then
    echo -e "\n$yellow \bFound existing IAM user:"
    echo $blue; printf '%s\n' "${getUser[@]}"

    echo $yellow; read -p "Delete IAM user(s)? [Y/N] " response

    # check for response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
      # loop through array of IAM users
      for i in "${getUser[@]}"; do
        # populate array with a user's access key IDs
        getUserKeys=($(aws iam list-access-keys \
          --user-name "$i" \
          --query AccessKeyMetadata[*].AccessKeyId \
          --output text)
        )

        # do if user has access key
        if [ ${#getUserKeys[@]} -ne 0 ]; then
          # loop through list of access key IDs
          for k in "${getUserKeys[@]}"; do
            echo -e "\n$green \bRemoving access key ID: $k from user: $i..."
            aws iam delete-access-key --access-key $k --user-name "$i"
          done
        fi

        echo -e "\n$green \bDeleting IAM user: $i..."
        aws iam delete-user --user-name "$i"

        # delete array
        unset getUser
      done
    else
      echo -e "\n$green \bKeeping IAM user(s)!"
    fi
  else
    echo -e "\n$yellow \b No AWS IAM user found! $rs"
  fi

  echo -e "$green
  \b\b######################################################
  \b\b##  Create New AWS IAM User  #########################
  \b\b######################################################"

  # delete group vars
  unset userNameValid AED_USER

  # do while new username is invalid
  while [ "$userNameValid" != true ]; do
    # prompt for new IAM username
    echo $yellow;
    read -p "Enter name for new IAM user, e.g name_ec2_admin: " AED_USER

    # check for existing IAM username; kick back to while loop if found
    # if $(aws iam list-users | grep -q "$AED_USER"); then
    if echo "${getUser[@]}" | grep -q -w "$AED_USER"; then
      echo -e "\n$red \bAWS IAM username already exists: $AED_USER $rs"
    else
      userNameValid=true
    fi
  done

  # create IAM user
  echo -e "\n$green \bCreating IAM user: $AED_USER...\n$blue"
  aws iam create-user --user-name $AED_USER

  echo -e "\n$green \bAdding IAM user: $AED_USER to IAM group: $AED_GROUP..."
  aws iam add-user-to-group --user-name $AED_USER --group-name $AED_GROUP
}

aed_iamUserKeys() {
  echo -e "$green
  \b\b#######################################################
  \b\b##  Create IAM User Access Keys  ######################
  \b\b#######################################################"

  # create IAM user access key; redirect awk output to file
  echo -e "\n$green \bCreating an access key for IAM user: $AED_USER..."
  aws iam create-access-key --user-name $AED_USER | \
    awk '/AccessKeyId/ || /SecretAccessKey/ { \
    gsub(/"/, ""); \
    gsub(/,/, ""); \
    gsub(/:/, "="); \
    gsub(/AccessKeyId/, "aws_access_key_id ", $1); \
    gsub(/SecretAccessKey/, "aws_secret_access_key ", $1); \
    print $1,$2}' > $AWS_CRD_TMP

  # insert profile name to top of temp AWS credentials file
  sed -i '' '1i\
    [default]\
    ' $AWS_CRD_TMP

    # delete AWS config file, recreate, change permissions & insert values
    echo -e "\n$green \bCreating Localhost AWS configuration..."
    if [ -f $AWS_CFG ]; then
      rm -f $AWS_CFG &>/dev/null
    fi
    touch $AWS_CFG
    chmod =,u+rw $AWS_CFG
    echo "[default]" >> $AWS_CFG
    echo "output = json" >> $AWS_CFG
    echo "region = us-west-1" >> $AWS_CFG # us-east-1, us-east-2, us-west-2

  echo -e "$green
  \b\b#######################################################
  \b\b##  Delete Root Access Keys  ##########################
  \b\b#######################################################"

  # populate array with a root's access key IDs
  getRootKeys=($(aws iam list-access-keys \
    --query AccessKeyMetadata[*].AccessKeyId \
    --output text)
  )

  # do if root has access key
  if [ ${#getRootKeys[@]} -ne 0 ]; then
    # loop through list of access key IDs
    for k in "${getRootKeys[@]}"; do
      echo -e "\n$green \bRemoving access key ID: $k from root..."
      aws iam delete-access-key --access-key $k
    done
  fi

  # overwrite localhost AWS credentials file
  echo -e "\n$green \bUpdating localhost AWS credentials for new IAM user: \
  \b\b$AED_USER...\n$blue"
  mv -f $AWS_CRD_TMP $AWS_CREDS

  # symlink AWS config & credentials files to default location
  echo -e "\n$green \bCreating symlinks to AWS credentials in default
  \b\blocation..."
  ln -sf $AWS_CFG $AWS_DOTFILE
  ln -sf $AWS_CRD $AWS_DOTFILE
}
