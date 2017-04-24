#!/usr/bin/env bash

#####################################################
##  filename:   iam.sh                             ##
##  path:       ~/src/deploy/cloud/aws/            ##
##  purpose:    IAM group, policy, user            ##
##  date:       04/22/2017                         ##
##  repo:       https://github.com/DevOpsEtc/aced  ##
##  clone path: ~/aced/app/                        ##
#####################################################

iam() {
  echo -e "\n$white \b****  IAM: Install Tasks  ****"
  iam_keys_create root # check/create IAM access keys; pass root as argument
  iam_group_create     # check/create IAM group
  iam_policy_create    # create/embed inline IAM group policies
  iam_user_create      # check/create IAM user
  iam_keys_create      # check/create IAM access keys
}

iam_keys_rotate() {
  echo -e "\n$white \b****  IAM: Access Key Rotation  ****"
  iam_keys_create
}

iam_group_create() {
  echo -e "\n$white \b####  IAM: Group Creation  ####"

  echo -e "\n$green \bChecking for existing IAM groups..."
  iam_groups=($(aws iam list-groups \
    --query Groups[*].GroupName \
    --output text)
  )
  cmd_check

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
        cmd_check

        if [ ${#iam_users[@]} -gt 0 ]; then
          for u in "${iam_users[@]}"; do
            echo -e "\n$green \bRemoving $g's user: $u..."
            aws iam remove-user-from-group \
              --user-name $u \
              --group-name "$g"
            cmd_check
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
        cmd_check

        if [ ${#iam_policies[@]} -gt 0 ]; then
          for p in "${iam_policies[@]}"; do
            echo -e "\n$green \bRemoving $g's policy: $p..."
            aws iam delete-group-policy \
              --group-name "$g" \
              --policy-name "$p"
            cmd_check
          done
        else
          echo -e "\n$blue \bNo policies in group: $g!"
        fi

        echo -e "\n$green \bDeleting IAM group: $g..."
        aws iam delete-group --group-name "$g"
        cmd_check
      else
        echo -e "\n$yellow \bDid not remove IAM group: $g!"
      fi
    done # end loop: iam_groups
  else
    echo -e "\n$blue \bNo IAM groups found!"
  fi

  echo -e "\n$green \bCreating IAM group: $iam_group..."
  echo $blue; aws iam create-group --group-name $iam_group
  cmd_check
} # end func: iam_group_create

iam_policy_create() {
  echo -e "\n$white \b****  IAM: Policy Creation  ****"

  echo -e "\n$green \bFetching AWS account ID..."
  aws_account=$(aws sts get-caller-identity --query Account --output text)
  cmd_check

  echo -e "\n$green \bEmbedding inline policy: $iam_policy_iam..."
  aws iam put-group-policy \
    --group-name $iam_group \
    --policy-name $iam_policy_iam \
    --policy-document \
    '{
      "Version": "2012-10-17",
      "Statement": {
        "Sid": "AllowUserToSeeAndManageOwnAccessKeys",
        "Effect": "Allow",
        "Action": ["iam:*AccessKey*", "iam:GetUser"],
        "Resource": "arn:aws:iam::'$aws_account':user/${aws:username}"
      }
    }'
  cmd_check

  echo -e "\n$green \bEmbedding inline policy: $iam_policy_ec2..."
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
  cmd_check
} # end func: iam_policy_create

iam_user_create() {
  echo -e "\n$white \b****  IAM: User Creation  ****"

  echo -e "\n$green \bChecking for existing IAM users..."
  iam_users=($(aws iam list-users \
    --query Users[*].UserName \
    --output text)
  )
  cmd_check

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
        cmd_check

        if [ ${#iam_groups[@]} -gt 0 ]; then
          for g in "${iam_groups[@]}"; do
            echo -e "\n$green \bRemoving $u from group: $g..."
            aws iam remove-user-from-group --user-name "$u" --group-name "$g"
            cmd_check
          done
        else
          echo -e "\n$blue \bNo group membership for IAM user: $u!"
        fi

        # invoke func: check/remove IAM user access keys
        iam_keys_remove $u

        echo -e "\n$green \bDeleting IAM user: $u..."
        aws iam delete-user --user-name "$u"
        cmd_check
      else
        echo -e "\n$blue \bDid not delete IAM user: $u"
      fi
    done # end loop: u in "${iam_users[@]}"
  else
    echo -e "\n$blue \bNo IAM users found!"
  fi # end conditional: [ ${#iam_users[@]} -gt 0 ]

  echo -e "\n$green \bCreating $iam_user... \n$blue"
  aws iam create-user --user-name "$iam_user"
  aws iam wait user-exists --user-name "$iam_user" &
  activity_show
  cmd_check

  echo -e "\n$green \bAdding $iam_user to group: $iam_group..."
  aws iam add-user-to-group --user-name $iam_user --group-name $iam_group
  cmd_check
} # end func: iam_user_create

iam_keys_remove() {
  argument_check
  echo -e "\n$green \bChecking existing access keys for user: $1... "
  if [ "$1" == "root" ]; then
    iam_keys=($(aws iam list-access-keys \
      --query AccessKeyMetadata[*].AccessKeyId \
      --output text)
    )
    cmd_check
  else
    iam_keys=($(aws iam list-access-keys \
    --user-name "$1" \
    --query AccessKeyMetadata[*].AccessKeyId \
    --output text)
    )
    cmd_check
  fi

  if [ ${#iam_keys[@]} -gt 0 ]; then
    for k in "${iam_keys[@]}"; do
      echo -e "\n$green \bDeleting $1's access key ID: $k..."
      if [ "$1" == "root" ]; then
        aws iam delete-access-key --access-key $k
      else
        aws iam delete-access-key --access-key $k --user-name "$1"
      fi
      cmd_check
    done
  else
    echo -e "\n$blue \bNo access keys found for IAM user: $1..."
  fi
} # end func: iam_keys_remove

iam_keys_create() {
  if [ "$1" == "root" ]; then
    [[ -f $down1/$root_keys ]] && rm -f $down1/$root_keys
    [[ -f $down2/$root_keys ]] && rm -f $down2/$root_keys

    echo -e "\n$white \b****  IAM: Root Access Key Creation  ****"
    echo -e "$yellow \
    \n  1. Open $aws_sec_root \
    \n  2. Sign in to your account if prompted \
    \n  3. Click \"Continue to Security Credentials\" if message appears \
    \n  4. Expand \"Access Keys (Access Key ID and Secret Access Key)\" \
    \n  5. Delete an access key if needed (only two allowed) \
    \n  6. Click button \"Create New Access Key\" \
    \n  7. Click button \"Download Key File\" \
    $reset"

    echo -e "\n$white \b****  Browser: Opening AWS Security Credentials  ****"
    sleep 2
    open $aws_sec_root

    echo -e "\n$yellow \bWaiting for you to download key file to: ~/Desktop \
      \b\b\b\b\b\bor ~/Downloads"

    # display activity indicator while checking for existence of file
    echo $cur_hide
    while true; do
      [[ -f $down1/$root_keys ]] && { rootkeys=$down1/$root_keys; break; }
      [[ -f $down2/$root_keys ]] && { rootkeys=$down2/$root_keys; break; }
      act_cur_frame=$(( (act_cur_frame+1) %4 ))
      printf "\b${blue}${act_frames:$act_cur_frame:1}"
      sleep .1
    done
    echo $cur_show && echo $cur_show # yes, twice is right

    echo -e "$blue \bFound: $rootkeys"

    # invoke func: process/push AWS credentials
    aws_cli_config root $rootkeys
  else
    echo -e "\n$white \b****  IAM: User Access Key Creation  ****"

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
    cmd_check

    iam_keys_remove root

    aws_cli_config $aced_keys/cred_tmp
  fi
} # end func: iam_keys_create
