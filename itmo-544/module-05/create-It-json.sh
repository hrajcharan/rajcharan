#!/bin/bash

ltconfigfile="./config.json"

if [ -a "$ltconfigfile" ]; then
  echo "You have already created the launch-template-data file ./config.json..."
  exit 1
elif [ "$#" -lt 18 ]; then
  echo "You don't have enough variables in your arguments.txt. Run: bash ./create-lt-json.sh \$(< /path/to/arguments.txt)"
  exit 1
else
  echo 'Creating launch template data file ./config.json...'

  echo "Finding and storing the subnet IDs for Availability Zone 1 and 2..."
  SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${10}")
  SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${11}")
  echo "Subnet for AZ 1: $SUBNET2A"
  echo "Subnet for AZ 2: $SUBNET2B"

  if [ -z "$SUBNET2A" ] || [ -z "$SUBNET2B" ]; then
    echo "Error: Subnet IDs could not be retrieved. Check your AWS CLI setup or the Availability Zone values."
    exit 1
  fi

  # Base64 conversion of user-data script
  BASECONVERT=$(base64 -w 0 < "${6}")
  if [ -z "$BASECONVERT" ]; then
    echo "Error: Failed to convert ${6} to Base64. Ensure the file exists and is accessible."
    exit 1
  fi

  # Create JSON configuration
  JSON="{
    \"NetworkInterfaces\": [
        {
            \"DeviceIndex\": 0,
            \"AssociatePublicIpAddress\": true,
            \"Groups\": [
                \"${4}\"
            ],
            \"SubnetId\": \"$SUBNET2A\",
            \"DeleteOnTermination\": true
        }
    ],
    \"ImageId\": \"${1}\",
    \"InstanceType\": \"${2}\",
    \"KeyName\": \"${3}\",
    \"UserData\": \"$BASECONVERT\",
    \"Placement\": {
        \"AvailabilityZone\": \"${10}\"
    }
  }"

  echo "$JSON" > "$ltconfigfile"

  if [ $? -eq 0 ]; then
    echo "Launch template data file ./config.json created successfully."
  else
    echo "Error: Failed to write ./config.json."
    exit 1
  fi
fi
