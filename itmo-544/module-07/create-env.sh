#!/bin/bash

# Function to trim leading and trailing spaces
trim_spaces() {
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Trim spaces for all input variables
AMI_ID=$(trim_spaces "${1}")
INSTANCE_TYPE=$(trim_spaces "${2}")
KEY_NAME=$(trim_spaces "${3}")
SECURITY_GROUP=$(trim_spaces "${4}")
MIN_INSTANCES=$(trim_spaces "${5}")
USER_DATA_FILE=$(trim_spaces "${6}")
AVAILABILITY_ZONE1=$(trim_spaces "${7}")
LOAD_BALANCER_NAME=$(trim_spaces "${8}")
TARGET_GROUP_NAME=$(trim_spaces "${9}")
AVAILABILITY_ZONE2=$(trim_spaces "${10}")
AVAILABILITY_ZONE3=$(trim_spaces "${11}")
MODULE_NAME=$(trim_spaces "${12}")
ASG_NAME=$(trim_spaces "${13}")
LAUNCH_TEMPLATE_NAME=$(trim_spaces "${14}")
ASG_MIN=$(trim_spaces "${15}")
ASG_MAX=$(trim_spaces "${16}")
ASG_DESIRED=$(trim_spaces "${17}")
RDS_INSTANCE_ID=$(trim_spaces "${18}")
IAM_PROFILE_NAME=$(trim_spaces "${19}")
S3_BUCKET_RAW=$(trim_spaces "${20}")
S3_BUCKET_FINISHED=$(trim_spaces "${21}")

echo "Finding and storing the subnet IDs for the defined Availability Zones..."
SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=$AVAILABILITY_ZONE2")
SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=$AVAILABILITY_ZONE3")
SUBNET2C=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=$AVAILABILITY_ZONE1")
echo "Subnets found: $SUBNET2A, $SUBNET2B, $SUBNET2C"

echo "Creating launch template '$LAUNCH_TEMPLATE_NAME'..."
aws ec2 create-launch-template \
    --launch-template-name "$LAUNCH_TEMPLATE_NAME" \
    --version-description version1 \
    --launch-template-data file://config.json


echo "Creating load balancer '$LOAD_BALANCER_NAME'..."
aws elbv2 create-load-balancer \
    --name "$LOAD_BALANCER_NAME" \
    --subnets $SUBNET2A $SUBNET2B $SUBNET2C \
    --security-groups "$SECURITY_GROUP" \
    --tags Key=Name,Value="$MODULE_NAME"

ELBARN=$(aws elbv2 describe-load-balancers --names "$LOAD_BALANCER_NAME" --output=text --query='LoadBalancers[*].LoadBalancerArn')
echo "*****************************************************************"
echo "Printing ELB ARN: $ELBARN"
echo "*****************************************************************"

echo "Waiting for ELB to become available..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ELBARN
echo "ELB is now available."

MYVPCID=$(aws ec2 describe-vpcs --output=text --query='Vpcs[*].VpcId')
echo "VPC ID: $MYVPCID"

echo "Creating target group '$TARGET_GROUP_NAME'..."
aws elbv2 create-target-group \
    --name "$TARGET_GROUP_NAME" \
    --protocol HTTP \
    --port 80 \
    --target-type instance \
    --vpc-id $MYVPCID

TGARN=$(aws elbv2 describe-target-groups --names "$TARGET_GROUP_NAME" --output=text --query='TargetGroups[*].TargetGroupArn')
echo "Target group ARN: $TGARN"

echo "Creating elbv2 listener..."
aws elbv2 create-listener --load-balancer-arn $ELBARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TGARN
echo "Created elbv2 listener."

echo "Creating auto-scaling group '$ASG_NAME'..."
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name "$ASG_NAME" \
    --launch-template LaunchTemplateName="$LAUNCH_TEMPLATE_NAME" \
    --target-group-arns $TGARN \
    --health-check-type ELB \
    --health-check-grace-period 120 \
    --min-size "$ASG_MIN" \
    --max-size "$ASG_MAX" \
    --desired-capacity "$ASG_DESIRED" \
    --tags Key=Name,Value="$MODULE_NAME"

# Tag EC2 Instances
EC2IDS=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=pending,running" \
    --output=text \
    --query='Reservations[*].Instances[*].InstanceId')

if [ -n "$EC2IDS" ]; then
    echo "Tagging EC2 instances with '$MODULE_NAME'..."
    aws ec2 create-tags --resources $EC2IDS --tags Key=Name,Value="$MODULE_NAME"
    echo "Tagged EC2 Instances: $EC2IDS"

    # Wait for instances to be running
    echo "Waiting for EC2 instances to be in running state..."
    aws ec2 wait instance-running --instance-ids $EC2IDS
    echo "Instances are up and running!"
else
    # No EC2 instances found
    echo "No EC2 instances found to tag or wait for."
fi

# Create S3 buckets
aws s3api create-bucket --bucket "$S3_BUCKET_RAW" --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
aws s3api create-bucket --bucket "$S3_BUCKET_FINISHED" --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
echo "S3 buckets '$S3_BUCKET_RAW' and '$S3_BUCKET_FINISHED' created."

# Create RDS subnet group
echo "Creating RDS subnet group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name "$RDS_INSTANCE_ID-subnet-group" \
    --db-subnet-group-description "Subnet group for $RDS_INSTANCE_ID" \
    --subnet-ids $SUBNET2A $SUBNET2B $SUBNET2C \
    --tags Key=Name,Value="$MODULE_NAME"
echo "Created RDS subnet group '$RDS_INSTANCE_ID-subnet-group'."

# Create RDS instance from snapshot
echo "Creating RDS instance '$RDS_INSTANCE_ID' from snapshot 'module06fullschemasnapshot'..."
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier "$RDS_INSTANCE_ID" \
    --db-snapshot-identifier "module06fullschemasnapshot" \
    --vpc-security-group-ids sg-04d74d95a88ed4a91 \
    --db-subnet-group-name "$RDS_INSTANCE_ID-subnet-group" \
    --tags Key=Name,Value="$MODULE_NAME"
echo "Created RDS instance '$RDS_INSTANCE_ID' from snapshot."

# Wait for the RDS instance to be available
echo "Waiting for RDS instance '$RDS_INSTANCE_ID' to become available..."
aws rds wait db-instance-available --db-instance-identifier "$RDS_INSTANCE_ID"
echo "RDS instance '$RDS_INSTANCE_ID' is now available."

echo "Printing DNS name of the load balancer..."
DNSNAME=$(aws elbv2 describe-load-balancers --names "$LOAD_BALANCER_NAME" --output=text --query='LoadBalancers[*].DNSName')
echo "DNS URL: http://$DNSNAME"