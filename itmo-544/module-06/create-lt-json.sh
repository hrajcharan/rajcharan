#!/bin/bash

ltconfigfile="./config.json"

# Function to trim whitespace, newlines, and carriage returns
trim() {
  echo "$1" | tr -d '\n\r' | xargs
}

if [ -a "$ltconfigfile" ]; then
  echo "You have already created the launch-template-data file ./config.json..."
  exit 1
elif [ "$#" -eq 0 ]; then
  echo "You don't have enough variables in your arguments.txt, perhaps you forgot to run: bash ./create-lt-json.sh \$(< ~/arguments.txt)"
  exit 1
else
  echo 'Creating launch template data file ./config.json...'

  echo "Finding and storing the subnet IDs for defined in arguments.txt Availability Zone 1 and 2..."
  SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=$(trim "${10}")")
  SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=$(trim "${11}")")
  echo "$SUBNET2A"
  echo "$SUBNET2B"

  # Convert the user-data file to a base64 string
  BASECONVERT=$(base64 -w 0 < "$(trim "${6}")")

  # Create JSON configuration
  JSON="{
    \"NetworkInterfaces\": [
        {
            \"DeviceIndex\": 0,
            \"AssociatePublicIpAddress\": true,
            \"Groups\": [
                \"$(trim "${4}")\"
            ],
            \"SubnetId\": \"$SUBNET2A\",
            \"DeleteOnTermination\": true
        }
    ],
    \"ImageId\": \"$(trim "${1}")\",
    \"InstanceType\": \"$(trim "${2}")\",
    \"KeyName\": \"$(trim "${3}")\",
    \"UserData\": \"$BASECONVERT\",
    \"Placement\": {
        \"AvailabilityZone\": \"$(trim "${10}")\"
    }
  }"

  # Save JSON to a file
  echo "$JSON" > ./config.json

  # Check if the file was created successfully
  if [ $? -eq 0 ]; then
    echo "Launch template data file ./config.json created successfully."
  else
    echo "Error: Failed to write ./config.json."
    exit 1
  fi
fi
