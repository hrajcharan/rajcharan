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

  # Trimming spaces and newline characters from input variables
  IMAGE_ID=$(echo "${1}" | xargs)
  INSTANCE_TYPE=$(echo "${2}" | xargs)
  KEY_NAME=$(echo "${3}" | xargs)
  SECURITY_GROUPS=$(echo "${4}" | xargs)
  USER_DATA_FILE=$(echo "${6}" | xargs)
  AVAILABILITY_ZONE_1=$(echo "${10}" | xargs)
  AVAILABILITY_ZONE_2=$(echo "${11}" | xargs)
  IAM_PROFILE_NAME=$(echo "${20}" | xargs)

  echo "Finding and storing the subnet IDs for Availability Zone 1 and 2..."
  SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${AVAILABILITY_ZONE_1}")
  SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${AVAILABILITY_ZONE_2}")
  echo $SUBNET2A
  echo $SUBNET2B

  # Convert the user-data file to a base64 string without line breaks
  BASECONVERT=$(base64 -w 0 < $USER_DATA_FILE)

  JSON="{
      \"NetworkInterfaces\": [
          {
              \"DeviceIndex\": 0,
              \"AssociatePublicIpAddress\": true,
              \"Groups\": [
                  \"$SECURITY_GROUPS\"
              ],
              \"SubnetId\": \"$SUBNET2A\",
              \"DeleteOnTermination\": true
          }
      ],
      \"ImageId\": \"$IMAGE_ID\",
      \"IamInstanceProfile\" : {
        \"Name\": \"$IAM_PROFILE_NAME\"
      }, 
      \"InstanceType\": \"$INSTANCE_TYPE\",
      \"KeyName\": \"$KEY_NAME\",
      \"UserData\": \"$BASECONVERT\",
      \"Placement\": {
          \"AvailabilityZone\": \"$AVAILABILITY_ZONE_1\"
      }
  }"

  # Save JSON to a file
  echo $JSON > ./config.json
  echo "Launch template data file ./config.json created successfully."
fi
