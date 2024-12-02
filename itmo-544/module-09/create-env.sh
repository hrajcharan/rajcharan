#!/bin/bash

# Create ELB, RDS instance, Auto Scaling Group (ASG), and other resources

# ${1} ami-085f9c64a9b75eed5
# ${2} t2.micro
# ${3} itmo-544-2024
# ${4} sg-0c7709a929dbfbb4d
# ${5} 3
# ${6} install-env.sh
# ${7} us-east-2a
# ${8} jrh-elb
# ${9} jrh-tg
# ${10} us-east-2a
# ${11} us-east-2b
# ${12} us-east-2c
# ${13} module-08
# ${14} asg name
# ${15} launch-template name
# ${16} asg min
# ${17} asg max
# ${18} asg desired
# ${19} RDS Database Instance Identifier
# ${20} IAM Instance Profile Name
# ${21} S3 Bucket Raw
# ${22} S3 Bucket Finished
# ${23} sns topic
# ${24} sns sub email

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


# Define file paths for the images
VEGETA_IMAGE="vegeta.jpg"
KNUTH_IMAGE="knuth.jpg"

# Create S3 buckets
aws s3api create-bucket --bucket ${21} --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
aws s3api create-bucket --bucket ${22} --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
echo "S3 buckets '${21}' and '${22}' created."

# Upload images to the raw bucket
aws s3 cp $VEGETA_IMAGE s3://${21}/
aws s3 cp $KNUTH_IMAGE s3://${21}/
echo "Uploaded images to bucket '${21}'."

aws s3api put-public-access-block --bucket ${21} --public-access-block-configuration "BlockPublicPolicy=false"
aws s3api put-bucket-policy --bucket ${21} --policy file://raw-bucket-policy.json

# Create RDS subnet group
echo "Creating RDS subnet group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name ${19}-subnet-group \
    --db-subnet-group-description "Subnet group for ${19}" \
    --subnet-ids $SUBNET2A $SUBNET2B $SUBNET2C \
    --tags Key=Name,Value=${13}
echo "Created RDS subnet group '${19}-subnet-group'."

# Create RDS instance from snapshot
echo "Creating RDS instance '${19}' from snapshot 'module06fullschemasnapshot'..."
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier "${19}" \
    --db-snapshot-identifier "module06fullschemasnapshot" \
    --vpc-security-group-ids sg-04d74d95a88ed4a91 \
    --db-subnet-group-name "${19}-subnet-group" \
    --tags Key=Name,Value="${13}"
echo "Created RDS instance '${19}' from snapshot."

# Wait for the RDS instance to be available
echo "Waiting for RDS instance '${19}' to become available..."
aws rds wait db-instance-available --db-instance-identifier "${19}"
echo "RDS instance '${19}' is now available."

# Modify RDS instance
aws rds modify-db-instance \
    --db-instance-identifier ${19} \
    --manage-master-user-password
echo "Modified RDS instance '${19}'."


# Create SNS Topic
echo "Creating SNS Topic '${23}'..."
SNS_TOPIC_ARN=$(aws sns create-topic --name ${23} --query 'TopicArn' --output text)
echo "SNS Topic '${23}' created."
echo "Topic ARN: $SNS_TOPIC_ARN"

# Subscribe the email address to the SNS Topic
echo "Subscribing ${24} to the SNS Topic '${23}'..."
aws sns subscribe \
    --topic-arn "$SNS_TOPIC_ARN" \
    --protocol email \
    --notification-endpoint ${24}

echo "Subscription request sent to ${24}. Please check your email for confirmation."


echo "Printing DNS name of the load balancer..."
DNSNAME=$(aws elbv2 describe-load-balancers --names ${8} --output=text --query='LoadBalancers[*].DNSName')
echo "DNS URL: http://$DNSNAME"



