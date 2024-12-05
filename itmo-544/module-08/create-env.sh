#!/bin/bash

# Trim newline and carriage return characters
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
IAM_PROFILE_NAME=$(echo "${20}" | tr -d '\n\r')
S3_BUCKET_RAW=$(echo "${21}" | tr -d '\n\r')
S3_BUCKET_FINISHED=$(echo "${22}" | tr -d '\n\r')
SNS_TOPIC=$(echo "${23}" | tr -d '\n\r')
SNS_SUB_EMAIL=$(echo "${24}" | tr -d '\n\r')

echo "Finding and storing the subnet IDs for the defined Availability Zones..."
SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${AZ1}")
SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${AZ2}")
SUBNET2C=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${AZ3}")
echo "Subnets found: $SUBNET2A, $SUBNET2B, $SUBNET2C"

echo "Creating launch template '${LAUNCH_TEMPLATE_NAME}'..."
aws ec2 create-launch-template \
    --launch-template-name ${LAUNCH_TEMPLATE_NAME} \
    --version-description version1 \
    --launch-template-data file://config.json


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
aws elbv2 create-target-group \
    --name ${TARGET_GROUP_NAME} \
    --protocol HTTP \
    --port 80 \
    --target-type instance \
    --vpc-id $MYVPCID

TGARN=$(aws elbv2 describe-target-groups --names ${TARGET_GROUP_NAME} --output=text --query='TargetGroups[*].TargetGroupArn')
echo "Target group ARN: $TGARN"

echo "Creating elbv2 listener..."
aws elbv2 create-listener --load-balancer-arn $ELBARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TGARN
echo "Created elbv2 listener."

echo "Creating auto-scaling group '${ASG_NAME}'..."
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name ${ASG_NAME} \
    --launch-template LaunchTemplateName=${LAUNCH_TEMPLATE_NAME} \
    --target-group-arns $TGARN \
    --health-check-type ELB \
    --health-check-grace-period 120 \
    --min-size ${ASG_MIN_SIZE} \
    --max-size ${ASG_MAX_SIZE} \
    --desired-capacity ${ASG_DESIRED_CAPACITY} \
    --tags Key=Name,Value="${TAG_VALUE}"

# Tag EC2 Instances
echo "Tagging EC2 instances with '${TAG_VALUE}'..."
EC2IDS=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=pending,running" \
    --output=text \
    --query='Reservations[*].Instances[*].InstanceId')

EC2IDS=$(echo "$EC2IDS" | tr -d '\n\r' | xargs)
echo "EC2IDS: '$EC2IDS'"

if [ "$EC2IDS" != "" ]; then
    aws ec2 create-tags --resources $EC2IDS --tags Key=Name,Value=${TAG_VALUE}
    echo "Tagged EC2 Instances: $EC2IDS"
else
    echo "No EC2 instances found to tag."
fi

# Wait for instances to be running
if [ "$EC2IDS" != "" ]; then
    echo "Waiting for EC2 instances to be in running state..."
    aws ec2 wait instance-running --instance-ids $EC2IDS
    echo "Instances are up and running!"
else
    echo "No EC2 instances found to wait for."
fi

# Define file paths for the images
VEGETA_IMAGE="vegeta.jpg"
KNUTH_IMAGE="knuth.jpg"

# Create S3 buckets
aws s3api create-bucket --bucket ${S3_BUCKET_RAW} --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
aws s3api create-bucket --bucket ${S3_BUCKET_FINISHED} --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
echo "S3 buckets '${S3_BUCKET_RAW}' and '${S3_BUCKET_FINISHED}' created."

# Upload images to the raw bucket
aws s3 cp $VEGETA_IMAGE s3://${S3_BUCKET_RAW}/
aws s3 cp $KNUTH_IMAGE s3://${S3_BUCKET_RAW}/
echo "Uploaded images to bucket '${S3_BUCKET_RAW}'."

aws s3api put-public-access-block --bucket ${S3_BUCKET_RAW} --public-access-block-configuration "BlockPublicPolicy=false"
aws s3api put-bucket-policy --bucket ${S3_BUCKET_RAW} --policy file://raw-bucket-policy.json

# Create RDS subnet group
echo "Creating RDS subnet group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name ${RDS_DB_NAME}-subnet-group \
    --db-subnet-group-description "Subnet group for ${RDS_DB_NAME}" \
    --subnet-ids $SUBNET2A $SUBNET2B $SUBNET2C \
    --tags Key=Name,Value=${TAG_VALUE}
echo "Created RDS subnet group '${RDS_DB_NAME}-subnet-group'."

# Create RDS instance from snapshot
echo "Creating RDS instance '${RDS_DB_NAME}' from snapshot 'module06fullschemasnapshot'..."
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier "${RDS_DB_NAME}" \
    --db-snapshot-identifier "module06fullschemasnapshot" \
    --vpc-security-group-ids sg-0dddd670614115c9a \
    --db-subnet-group-name "${RDS_DB_NAME}-subnet-group" \
    --tags Key=Name,Value="${TAG_VALUE}"
echo "Created RDS instance '${RDS_DB_NAME}' from snapshot."

# Wait for the RDS instance to be available
echo "Waiting for RDS instance '${RDS_DB_NAME}' to become available..."
aws rds wait db-instance-available --db-instance-identifier "${RDS_DB_NAME}"
echo "RDS instance '${RDS_DB_NAME}' is now available."

# Modify RDS instance
aws rds modify-db-instance \
    --db-instance-identifier ${RDS_DB_NAME} \
    --manage-master-user-password
echo "Modified RDS instance '${RDS_DB_NAME}'."


echo "Printing DNS name of the load balancer..."
DNSNAME=$(aws elbv2 describe-load-balancers --names ${ELB_NAME} --output=text --query='LoadBalancers[*].DNSName')
echo "DNS URL: http://$DNSNAME"
