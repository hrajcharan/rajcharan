#!/bin/bash

# Function to trim whitespace, newlines, and carriage returns
trim() {
  echo "$1" | tr -d '\n\r' | xargs
}

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

# Trim all input variables
image_id=$(trim "${1}")
instance_type=$(trim "${2}")
key_name=$(trim "${3}")
security_group_ids=$(trim "${4}")
count=$(trim "${5}")
user_data_file=$(trim "${6}")
availability_zone=$(trim "${7}")
elb_name=$(trim "${8}")
target_group_name=$(trim "${9}")
subnet_az_a=$(trim "${10}")
subnet_az_b=$(trim "${11}")
subnet_az_c=$(trim "${12}")
tag_value=$(trim "${13}")
asg_name=$(trim "${14}")
launch_template_name=$(trim "${15}")
asg_min=$(trim "${16}")
asg_max=$(trim "${17}")
asg_desired=$(trim "${18}")
rds_db_name=$(trim "${19}")

# Finding and storing the subnet IDs for the defined Availability Zones
echo "Finding and storing the subnet IDs for the defined Availability Zones..."
SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${subnet_az_a}")
SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${subnet_az_b}")
SUBNET2C=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${subnet_az_c}")
echo "Subnets found: $SUBNET2A, $SUBNET2B, $SUBNET2C"

echo "Creating launch template '${launch_template_name}'..."
aws ec2 create-launch-template \
    --launch-template-name ${launch_template_name} \
    --version-description version1 \
    --launch-template-data file://config.json

echo "Creating load balancer '${elb_name}'..."
aws elbv2 create-load-balancer \
    --name ${elb_name} \
    --subnets $SUBNET2A $SUBNET2B $SUBNET2C \
    --security-groups ${security_group_ids} \
    --tags Key=Name,Value="${tag_value}"

ELBARN=$(aws elbv2 describe-load-balancers --names ${elb_name} --output=text --query='LoadBalancers[*].LoadBalancerArn')
echo "*****************************************************************"
echo "Printing ELB ARN: $ELBARN"
echo "*****************************************************************"

echo "Waiting for ELB to become available..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ELBARN
echo "ELB is now available."

MYVPCID=$(aws ec2 describe-vpcs --output=text --query='Vpcs[*].VpcId')
echo "VPC ID: $MYVPCID"

echo "Creating target group '${target_group_name}'..."
aws elbv2 create-target-group \
    --name ${target_group_name} \
    --protocol HTTP \
    --port 80 \
    --target-type instance \
    --vpc-id $MYVPCID

TGARN=$(aws elbv2 describe-target-groups --names ${target_group_name} --output=text --query='TargetGroups[*].TargetGroupArn')
echo "Target group ARN: $TGARN"

echo "Creating elbv2 listener..."
aws elbv2 create-listener --load-balancer-arn $ELBARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TGARN
echo "Created elbv2 listener."

echo "Creating auto-scaling group '${asg_name}'..."
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name ${asg_name} \
    --launch-template LaunchTemplateName=${launch_template_name} \
    --target-group-arns $TGARN \
    --health-check-type ELB \
    --health-check-grace-period 120 \
    --min-size ${asg_min} \
    --max-size ${asg_max} \
    --desired-capacity ${asg_desired} \
    --tags Key=Name,Value="${tag_value}"

# Tag EC2 Instances
echo "Tagging EC2 instances with '${tag_value}'..."
EC2IDS=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=pending,running" \
    --output=text \
    --query='Reservations[*].Instances[*].InstanceId')

if [ "$EC2IDS" != "" ]; then
    aws ec2 create-tags --resources $EC2IDS --tags Key=Name,Value=${tag_value}
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

# Create RDS subnet group
echo "Creating RDS subnet group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name ${rds_db_name}-subnet-group \
    --db-subnet-group-description "Subnet group for ${rds_db_name}" \
    --subnet-ids $SUBNET2A $SUBNET2B $SUBNET2C \
    --tags Key=Name,Value=${tag_value}
echo "Created RDS subnet group '${rds_db_name}-subnet-group'."

# Create RDS instance
echo "Creating RDS primary instance '${rds_db_name}'..."
aws rds create-db-instance \
    --db-instance-identifier "${rds_db_name}" \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --allocated-storage 20 \
    --db-subnet-group-name ${rds_db_name}-subnet-group \
    --vpc-security-group-ids ${security_group_ids} \
    --master-username controller \
    --manage-master-user-password \
    --tags Key=Name,Value=${tag_value}
echo "Created RDS primary instance '${rds_db_name}'."

# Wait for the primary RDS instance to be available
echo "Waiting for RDS instance '${rds_db_name}' to become available..."
aws rds wait db-instance-available --db-instance-identifier "${rds_db_name}"
echo "RDS primary instance '${rds_db_name}' is now available."

echo "Printing DNS name of the load balancer..."
DNSNAME=$(aws elbv2 describe-load-balancers --names ${elb_name} --output=text --query='LoadBalancers[*].DNSName')
echo "DNS URL: http://$DNSNAME"
