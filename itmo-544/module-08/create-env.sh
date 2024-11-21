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

echo "Finding and storing the subnet IDs for the defined Availability Zones..."
SUBNET2A=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${10}")
SUBNET2B=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${11}")
SUBNET2C=$(aws ec2 describe-subnets --output=text --query='Subnets[*].SubnetId' --filter "Name=availability-zone,Values=${12}")
echo "Subnets found: $SUBNET2A, $SUBNET2B, $SUBNET2C"

echo "Creating launch template '${15}'..."
aws ec2 create-launch-template \
    --launch-template-name ${15} \
    --version-description version1 \
    --launch-template-data file://config.json

echo "Creating load balancer '${8}'..."
aws elbv2 create-load-balancer \
    --name ${8} \
    --subnets $SUBNET2A $SUBNET2B $SUBNET2C \
    --security-groups ${4} \
    --tags Key=Name,Value="${13}"

ELBARN=$(aws elbv2 describe-load-balancers --names ${8} --output=text --query='LoadBalancers[*].LoadBalancerArn')
echo "*****************************************************************"
echo "Printing ELB ARN: $ELBARN"
echo "*****************************************************************"

echo "Waiting for ELB to become available..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ELBARN
echo "ELB is now available."

MYVPCID=$(aws ec2 describe-vpcs --output=text --query='Vpcs[*].VpcId')
echo "VPC ID: $MYVPCID"

echo "Creating target group '${9}'..."
aws elbv2 create-target-group \
    --name ${9} \
    --protocol HTTP \
    --port 80 \
    --target-type instance \
    --vpc-id $MYVPCID

TGARN=$(aws elbv2 describe-target-groups --names ${9} --output=text --query='TargetGroups[*].TargetGroupArn')
echo "Target group ARN: $TGARN"

echo "Creating elbv2 listener..."
aws elbv2 create-listener --load-balancer-arn $ELBARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TGARN
echo "Created elbv2 listener."

echo "Creating auto-scaling group '${14}'..."
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name ${14} \
    --launch-template LaunchTemplateName=${15} \
    --target-group-arns $TGARN \
    --health-check-type ELB \
    --health-check-grace-period 120 \
    --min-size ${16} \
    --max-size ${17} \
    --desired-capacity ${18} \
    --tags Key=Name,Value="${13}"

# Tag EC2 Instances
echo "Tagging EC2 instances with '${13}'..."
EC2IDS=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=pending,running" \
    --output=text \
    --query='Reservations[*].Instances[*].InstanceId')

if [ "$EC2IDS" != "" ]; then
    aws ec2 create-tags --resources $EC2IDS --tags Key=Name,Value=${13}
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
    --db-subnet-group-name ${19}-subnet-group \
    --db-subnet-group-description "Subnet group for ${19}" \
    --subnet-ids $SUBNET2A $SUBNET2B $SUBNET2C \
    --tags Key=Name,Value=${13}
echo "Created RDS subnet group '${19}-subnet-group'."

# Create RDS instance
echo "Creating RDS primary instance '${19}'..."
aws rds create-db-instance \
    --db-instance-identifier "${19}" \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --allocated-storage 20 \
    --db-subnet-group-name ${19}-subnet-group \
    --vpc-security-group-ids ${4} \
    --master-username controller \
    --manage-master-user-password \
    --tags Key=Name,Value=${13}
echo "Created RDS primary instance '${19}'."

# Wait for the primary RDS instance to be available
echo "Waiting for RDS instance '${19}' to become available..."
aws rds wait db-instance-available --db-instance-identifier "${19}"
echo "RDS primary instance '${19}' is now available."


echo "Printing DNS name of the load balancer..."
DNSNAME=$(aws elbv2 describe-load-balancers --names ${8} --output=text --query='LoadBalancers[*].DNSName')
echo "DNS URL: http://$DNSNAME"
