#!/usr/bin/env bash

#####################################################
##  filename:   iam.sh                             ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    IAM group, policy, user            ##
##  date:       03/22/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

iam() {
  echo -e "$white
  \b\b#########################################
  \b\b######  IAM: Keys/Group/Policy  #########
  \b\b#########################################"
  iam_keys_create root # check/create IAM access keys; pass root as argument
  iam_group_create     # check/create IAM group
  iam_policy_create    # create/embed inline IAM group policies
  iam_user_create      # check/create IAM user
  iam_keys_create      # check/create IAM access keys
}

iam_keys_rotate() {
  echo -e "$white
  \b\b#########################################
  \b\b####  IAM: User Access Key Rotation  ####
  \b\b#########################################"
  iam_keys_create
}

aws_config() {
  argument_check

  echo -e "\n$white \b****  AWS: Update $aced_nm Config  ****"

  echo -e "\n$green \bProcessing access key file: Access Key ID..."
  iam_key_id=$(awk '/AWSAccessKeyId/ \
    {gsub(/AWSAccessKeyId=/, ""); print}' $1)
  exit_code_check

  echo -e "\n$green \bProcessing access key file: Secret Access Key..."
  iam_key_secret=$(awk '/AWSSecretKey/ \
    {gsub(/AWSSecretKey=/, ""); print}' $1)
  exit_code_check

  echo -e "\n$green \bAWS configure: pushing extracted credentials..."
  aws configure set aws_access_key_id $iam_key_id \
    && aws configure set aws_secret_access_key $iam_key_secret
  exit_code_check

  echo -e "\n$green \bDeleting temporary credentials file... \n$blue"
  rm -f $1
  exit_code_check

  echo -e "\n$green \bAWS configure: pushing config..."
  aws configure set default.region $aws_region \
    && aws configure set default.output $aws_output
  exit_code_check
}

iam_group_create() {
  echo -e "\n$white \b####  EC2: Group Creation  ####"

  echo -e "\n$green \bChecking for existing IAM groups..."
  iam_groups=($(aws iam list-groups \
    --query Groups[*].GroupName \
    --output text)
    )
  exit_code_check

  if [ ${#iam_groups[@]} -gt 0 ]; then
    for g in "${iam_groups[@]}"; do
      echo -e "\n$blue \bIAM group found: $g"

      if [ $g == "$iam_group" ]; then
        group_rm=true
      else
        decision_response Remove IAM group: $g?

        [[ "$response" =~ [nN] ]] && group_rm=false
      fi

      if [ "$group_rm" != false  ]; then
        echo -e "\n$green \bChecking $g for users..."
        iam_users=($(aws iam get-group \
          --group-name "$g" \
          --query Users[*].UserName \
          --output text)
          )
        exit_code_check

        if [ ${#iam_users[@]} -gt 0 ]; then
          for u in "${iam_users[@]}"; do
            echo -e "\n$green \bRemoving $g's user: $u..."
            aws iam remove-user-from-group \
              --user-name $u \
              --group-name "$g"
            exit_code_check
          done
        else
          echo -e "\n$blue \bNo users in group: $g!"
        fi

        echo -e "\n$green \bChecking $g for policies..."
        iam_policies=($(aws iam list-group-policies \
          --group-name "$g" \
          --query PolicyNames[*] \
          --output text)
        )
        exit_code_check

        if [ ${#iam_policies[@]} -gt 0 ]; then
          for p in "${iam_policies[@]}"; do
            echo -e "\n$green \bRemoving $g's policy: $p..."
            aws iam delete-group-policy \
              --group-name "$g" \
              --policy-name "$p"
            exit_code_check
          done
        else
          echo -e "\n$blue \bNo policies in group: $g!"
        fi

        echo -e "\n$green \bDeleting IAM group: $g..."
        aws iam delete-group --group-name "$g"
        exit_code_check
      else
        echo -e "\n$yellow \bDid not remove IAM group: $g!"
      fi
    done # end loop: iam_groups
  else
    echo -e "\n$blue \bNo IAM groups found!"
  fi

  echo -e "\n$green \bCreating IAM group: $iam_group..."
  echo $blue; aws iam create-group --group-name $iam_group
  exit_code_check
}

iam_policy_create() {
  echo -e "\n$white \b****  IAM: Policy Creation  ****"

  echo -e "\n$green \bFetching AWS account ID..."
  aws_account=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[0].OwnerId' \
    --output text)
  exit_code_check

  echo -e "\n$green \bEmbedding IAM inline policy: $iam_policy_iam..."
  aws iam put-group-policy \
    --group-name $iam_group \
    --policy-name $iam_policy_iam \
    --policy-document \
    '{
      "Version": "2012-10-17",
      "Statement": {
        "Sid": "AllowUserToSeeAndManageOwnAccessKeys",
        "Effect": "Allow",
        "Action": ["iam:*AccessKey*"],
        "Resource": "arn:aws:iam::'$aws_account':user/${aws:username}"
      }
    }'
  exit_code_check

  echo -e "\n$green \bEmbedding IAM inline policy: $iam_policy_ec2..."
  aws iam put-group-policy \
    --group-name $iam_group \
    --policy-name $iam_policy_ec2 \
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
          "Resource": "arn:aws:ec2:*:'$aws_account':instance/*",
          "Condition": {
            "StringNotEquals": {
              "ec2:Region": "'$aws_region'",
              "ec2:InstanceType": "'$aws_type'"
            }
          }
        }
      ]
    }'
  exit_code_check
}

iam_user_create() {
  echo -e "\n$white \b****  IAM: User Creation  ****"

  echo -e "\n$green \bChecking for existing IAM users..."
  iam_users=($(aws iam list-users \
    --query Users[*].UserName \
    --output text)
  )
  exit_code_check

  if [ ${#iam_users[@]} -gt 0 ]; then
    for u in "${iam_users[@]}"; do
      echo -e "\n$blue \bIAM user found: $u"

      if [ $u == "$iam_user" ]; then
        user_rm=true
      else
        decision_response Remove IAM user $u?

        [[ "$response" =~ [nN] ]] && user_rm=false
      fi

      if [ "$user_rm" != false  ]; then
        echo -e "\n$green \bChecking $u's group membership..."
        iam_groups=($(aws iam list-groups-for-user \
          --user-name "$u" \
          --query Groups[*].GroupName \
          --output text)
        )
        exit_code_check

        if [ ${#iam_groups[@]} -gt 0 ]; then
          for g in "${iam_groups[@]}"; do
            echo -e "\n$green \bRemoving $u from group: $g..."
            aws iam remove-user-from-group --user-name "$u" --group-name "$g"
            exit_code_check
          done
        else
          echo -e "\n$blue \bNo group membership for IAM user: $u!"
        fi

        # invoke function to check/remove IAM user access keys
        iam_keys_remove $u

        echo -e "\n$green \bDeleting IAM user: $u..."
        aws iam delete-user --user-name "$u"
        exit_code_check
      else
        echo -e "\n$blue \bDid not delete IAM user: $u"
      fi
    done # end loop: u in "${iam_users[@]}"
  else
    echo -e "\n$blue \bNo IAM users found!"
  fi # end conditional: [ ${#iam_users[@]} -gt 0 ]

  echo -e "\n$green \bCreating $iam_user... \n$blue"
  aws iam create-user --user-name $iam_user
  exit_code_check

  echo -e "\n$green \bAdding $iam_user to group: $iam_group..."
  aws iam add-user-to-group --user-name $iam_user --group-name $iam_group
  exit_code_check
}

iam_keys_remove() {
  argument_check
  echo -e "\n$green \bChecking existing access keys for user: $1... "
  if [ "$1" == "root" ]; then
    iam_keys=($(aws iam list-access-keys \
      --query AccessKeyMetadata[*].AccessKeyId \
      --output text)
    )
    exit_code_check
  else
    iam_keys=($(aws iam list-access-keys \
    --user-name "$1" \
    --query AccessKeyMetadata[*].AccessKeyId \
    --output text)
    )
    exit_code_check
  fi

  if [ ${#iam_keys[@]} -gt 0 ]; then
    for k in "${iam_keys[@]}"; do
      echo -e "\n$green \bDeleting $1's access key ID: $k..."
      if [ "$1" == "root" ]; then
        aws iam delete-access-key --access-key $k
      else
        aws iam delete-access-key --access-key $k --user-name "$1"
      fi
      exit_code_check
    done
  else
    echo -e "\n$blue \bNo access keys found for IAM user: $1..."
  fi
}

iam_keys_create() {
  echo -e "\n$white \b****  IAM: User Access Key Creation  ****"

  if [ "$1" == "root" ]; then
    echo -e "$yellow
    \b\b\b\b1. Open $aws_sec_root
    \b\b\b\b2. Sign in to your account if prompted
    \b\b\b\b3. Click \"Continue to Security Credentials\" if message appears
    \b\b\b\b4. Expand \"Access Keys (Access Key ID and Secret Access Key)\"
    \b\b\b\b5. Delete an access key if needed (only two allowed)
    \b\b\b\b6. Click button \"Create New Access Key\"
    \b\b\b\b7. Click button \"Download Key File\""

    echo -e "\n$white \bOpening website in 3 seconds... \n$yellow"
    sleep 3
    open $aws_sec_root

    echo -e "$yellow \bWaiting for you to download rootkey.csv file to: \
    \n\n~/Desktop or ~/Downloads"

    # display activity indicator while checking for existence of file
    echo $cur_hide
    while true; do
      [[ -f $down1/$root_keys ]] && { rootkey=$down1/$root_keys; break; }
      [[ -f $down2/$root_keys ]] && { rootkey=$down2/$root_keys; break; }
      act_cur_frame=$(( (act_cur_frame+1) %4 ))
      printf "\b${blue}${act_frames:$act_cur_frame:1}"
      sleep .1
    done
    echo $cur_show

    echo -e "\n$blue \bFound: $rootkey"

    # invoke function to process/push AWS credentials
    aws_config $rootkey
  else
    iam_keys_remove $iam_user

    echo -e "\n$green \bCreating access keys for: $iam_user..."
    aws iam create-access-key \
    --user-name $iam_user \
    --output json \
    | awk '/AccessKeyId/ || /SecretAccessKey/ { \
    gsub(/"/, ""); \
    gsub(/,/, ""); \
    gsub(/: /, "="); \
    gsub(/AccessKeyId/, "AWSAccessKeyId", $1); \
    gsub(/SecretAccessKey/, "AWSSecretKey", $1); \
    print $1,$2}' >| $aced_keys/cred_tmp
    exit_code_check

    iam_keys_remove root

    aws_config $aced_keys/cred_tmp
  fi
}
