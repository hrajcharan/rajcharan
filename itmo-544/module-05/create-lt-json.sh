#!/bin/bash

ltconfigfile="./config.json"

# Check if config.json already exists
if [ -e $ltconfigfile ]; then
  echo "You have already created the launch-template-data file ./config.json..."
  exit 1
fi

# Check if arguments.txt exists and has content
if [ ! -s ~/arguments.txt ]; then
  echo "You don't have enough variables in your arguments.txt. Perhaps you forgot to run: bash ./create-lt-json.sh \$(< /fall2024/rharidasu/itmo-544/module-05/arguments.txt)"
  exit 1
fi

echo "Creating launch template data file ./config.json..."

echo "Finding and storing the subnet IDs for defined in arguments.txt Availability Zone 1 and 2..."
SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${10}")
SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${11}")
echo "Subnet 1: $SUBNET2A"
echo "Subnet 2: $SUBNET2B"

# Encode user data to base64
BASECONVERT=$(base64 -w 0 < ${6})

# Generate JSON using jq
JSON=$(jq -n --arg group "$4" --arg subnet "$SUBNET2A" --arg image "$1" --arg type "$2" --arg key "$3" --arg data "$BASECONVERT" --arg zone "$10" '{
    NetworkInterfaces: [
        {
            DeviceIndex: 0,
            AssociatePublicIpAddress: true,
            Groups: [$group],
            SubnetId: $subnet,
            DeleteOnTermination: true
        }
    ],
    ImageId: $image,
    InstanceType: $type,
    KeyName: $key,
    UserData: $data,
    Placement: { AvailabilityZone: $zone }
}')

echo "$JSON" > ./config.json
echo "Launch template data file created at ./config.json"
