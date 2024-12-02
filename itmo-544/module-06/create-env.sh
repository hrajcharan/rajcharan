#!/bin/bash

# Create ELB, RDS instance, Auto Scaling Group (ASG), and other resources

# ${1} image-id
# ${2} instance-type
# ${3} key-name
# ${4} security-group-ids
# ${5} count
# ${6} user-data file name
# ${7} availability-zone
# ${8} elb name
# ${9} target group name
# ${10} us-east-2a
# ${11} us-east-2b
# ${12} us-east-2c
# ${13} tag value (e.g., module-06)
# ${14} asg name
# ${15} launch template name
# ${16} asg min
# ${17} asg max
# ${18} asg desired
# ${19} rds database name

# Remove newline and carriage return characters from input variables
IMAGE_ID=$(echo "${1}" | tr -d '\n\r')
INSTANCE_TYPE=$(echo "${2}" | tr -d '\n\r')
KEY_NAME=$(echo "${3}" | tr -d '\n\r')
SECURITY_GROUPS=$(echo "${4}" | tr -d '\n\r')
COUNT=$(echo "${5}" | tr -d '\n\r')
USER_DATA_FILE=$(echo "${6}" | tr -d '\n\r')
AVAILABILITY_ZONE=$(echo "${7}" | tr -d '\n\r')
ELB_NAME=$(echo "${8}" | tr -d '\n\r')
TARGET_GROUP_NAME=$(echo "${9}" | tr -d '\n\r')
AZ1=$(echo "${10}" | tr -d '\n\r')
AZ2=$(echo "${11}" | tr -d '\n\r')
AZ3=$(echo "${12}" | tr -d '\n\r')
TAG_VALUE=$(echo "${13}" | tr -d '\n\r')
ASG_NAME=$(echo "${14}" | tr -d '\n\r')
LAUNCH_TEMPLATE_NAME=$(echo "${15}" | tr -d '\n\r')
ASG_MIN_SIZE=$(echo "${16}" | tr -d '\n\r')
ASG_MAX_SIZE=$(echo "${17}" | tr -d '\n\r')
ASG_DESIRED_CAPACITY=$(echo "${18}" | tr -d '\n\r')
RDS_DB_NAME=$(echo "${19}" | tr -d '\n\r')

# Finding and storing the subnet IDs for the defined Availability Zones...
echo "Finding and storing the subnet IDs for the defined Availability Zones..."
SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${AZ1}")
SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${AZ2}")
SUBNET2C=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${AZ3}")
echo "Subnets found: $SUBNET2A, $SUBNET2B, $SUBNET2C"

# Check if launch template already exists
TEMPLATE_EXISTS=$(aws ec2 describe-launch-templates --query "LaunchTemplates[?LaunchTemplateName=='${LAUNCH_TEMPLATE_NAME}'].LaunchTemplateName" --output text)

if [ "$TEMPLATE_EXISTS" == "${LAUNCH_TEMPLATE_NAME}" ]; then
    echo "Launch template '${LAUNCH_TEMPLATE_NAME}' already exists. Skipping creation."
else
    # Create launch template
    echo "Creating launch template '${LAUNCH_TEMPLATE_NAME}'..."
    aws ec2 create-launch-template \
        --launch-template-name ${LAUNCH_TEMPLATE_NAME} \
        --version-description version1 \
        --launch-template-data file://config.json
fi

echo "Creating load balancer '${ELB_NAME}'..."
aws elbv2 create-load-balancer \
    --name ${ELB_NAME} \
    --subnets $SUBNET2A $SUBNET2B $SUBNET2C \
    --security-groups ${SECURITY_GROUPS} \
    --tags Key=Name,Value="${TAG_VALUE}"

ELBARN=$(aws elbv2 describe-load-balancers --names ${ELB_NAME} --output=text --query='LoadBalancers[*].LoadBalancerArn')
echo "*****************************************************************"
echo "Printing ELB ARN: $ELBARN"
echo "*****************************************************************"

echo "Waiting for ELB to become available..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ELBARN
echo "ELB is now available."

MYVPCID=$(aws ec2 describe-vpcs --output=text --query='Vpcs[*].VpcId')
echo "VPC ID: $MYVPCID"

echo "Creating target group '${TARGET_GROUP_NAME}'..."
aws elbv2 crea
