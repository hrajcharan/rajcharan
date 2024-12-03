#!/bin/bash

ltconfigfile="./config.json"

if [ -a $ltconfigfile ]; then
  echo "You have already created the launch-template-data file ./config.json..."
  exit 1
elif [ $# = 0 ]; then
  echo "You don't have enough variables in your arguments.txt, perhaps you forgot to run: bash ./create-lt-json.sh \$(< ~/arguments.txt)"
  exit 1
else
  echo 'Creating launch template data file ./config.json...'

  # Trim spaces for all arguments
  for i in "$@"; do
    trimmed_args+=( "${i// /}" )
  done

  # Assign trimmed variables
  IMAGE_ID="${trimmed_args[0]}"
  INSTANCE_TYPE="${trimmed_args[1]}"
  KEY_NAME="${trimmed_args[2]}"
  SECURITY_GROUP="${trimmed_args[3]}"
  USER_DATA="${trimmed_args[5]}"
  AVAIL_ZONE1="${trimmed_args[9]}"
  AVAIL_ZONE2="${trimmed_args[10]}"
  IAM_ROLE="${trimmed_args[19]}"

  echo "Finding and storing the subnet IDs for Availability Zone 1 and 2..."
  SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=$AVAIL_ZONE1")
  SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=$AVAIL_ZONE2")
  echo $SUBNET2A
  echo $SUBNET2B

  # Convert user-data file to a base64 string
  BASECONVERT=$(base64 -w 0 < "$USER_DATA")

  # Create JSON configuration
  JSON="{
      \"NetworkInterfaces\": [
          {
              \"DeviceIndex\": 0,
              \"AssociatePublicIpAddress\": true,
              \"Groups\": [
                  \"$SECURITY_GROUP\"
              ],
              \"SubnetId\": \"$SUBNET2A\",
              \"DeleteOnTermination\": true
          }
      ],
      \"ImageId\": \"$IMAGE_ID\",
      \"IamInstanceProfile\" : {
        \"Name\": \"$IAM_ROLE\"
      }, 
      \"InstanceType\": \"$INSTANCE_TYPE\",
      \"KeyName\": \"$KEY_NAME\",
      \"UserData\": \"$BASECONVERT\",
      \"Placement\": {
          \"AvailabilityZone\": \"$AVAIL_ZONE1\"
      }
  }"

  # Redirect JSON to file
  echo $JSON > ./config.json

  echo "Launch template data file ./config.json created successfully!"
fi
