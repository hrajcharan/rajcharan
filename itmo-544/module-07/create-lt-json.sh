#!/bin/bash

ltconfigfile="./config.json"

# Function to trim leading and trailing spaces
trim_spaces() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

if [ -a $ltconfigfile ]; then
  echo "You have already created the launch-template-data file ./config.json..."
  exit 1
elif [ $# = 0 ]; then
  echo "You don't have enough variables in your arguments.txt, perhaps you forgot to run: bash ./create-lt-json.sh \$(< ~/arguments.txt)"
  exit 1
else
  echo 'Creating launch template data file ./config.json...'

  # Trim spaces from arguments
  AZ1=$(trim_spaces "${10}")
  AZ2=$(trim_spaces "${11}")
  IMAGE_ID=$(trim_spaces "${1}")
  INSTANCE_TYPE=$(trim_spaces "${2}")
  KEY_NAME=$(trim_spaces "${3}")
  GROUP_ID=$(trim_spaces "${4}")
  USER_DATA_FILE=$(trim_spaces "${6}")
  IAM_PROFILE_NAME=$(trim_spaces "${20}")

  echo "Finding and storing the subnet IDs for Availability Zone 1 and 2..."
  SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=$AZ1")
  SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=$AZ2")
  echo $SUBNET2A
  echo $SUBNET2B

  # Base64 encode the user-data file
  BASECONVERT=$(base64 -w 0 < "$USER_DATA_FILE")

  # Create JSON configuration for the launch template
  JSON="{
      \"NetworkInterfaces\": [
          {
              \"DeviceIndex\": 0,
              \"AssociatePublicIpAddress\": true,
              \"Groups\": [
                  \"$GROUP_ID\"
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
          \"AvailabilityZone\": \"$AZ1\"
      }
  }"

  # Redirecting the content of our JSON to a file
  echo $JSON > ./config.json

  echo "Launch template data file ./config.json has been created!"
fi
