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

# Trim spaces and remove newlines and carriage returns for input variables
SUBNET2A=$(echo "${10}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')
SUBNET2B=$(echo "${11}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')
SUBNET2C=$(echo "${12}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')
LAUNCH_TEMPLATE_NAME=$(echo "${15}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')
LB_NAME=$(echo "${8}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')
TG_NAME=$(echo "${9}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')
VPC_ID=$(echo "${13}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')
EC2_NAME=$(echo "${13}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')
RDS_ID=$(echo "${19}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')
S3_BUCKET_RAW=$(echo "${21}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')
S3_BUCKET_FINISHED=$(echo "${22}" | tr -d '\n\r' | sed 's/^ *//;s/ *$//')

echo "Finding and storing the subnet IDs for the defined Availability Zones..."
echo "Subnets found: $SUBNET2A, $SUBNET2B, $SUBNET2C"

echo "Creating launch template '${LAUNCH_TEMPLATE_NAME}'..."
aws ec2 create-launch-template \
    --launch-template-name "${LAUNCH_TEMPLATE_NAME}" \
    --version-description version1 \
    --launch-template-data file://config.json

echo "Creating load balancer '${LB_NAME}'..."
aws elbv2 create-load-balancer \
    --name "${LB_NAME}" \
    --subnets $SUBNET2A $SUBNET2B $SUBNET2C \
    --security-groups ${4} \
    --tags Key=Name,Value="${VPC_ID}"

ELBARN=$(aws elbv2 describe-load-balancers --names "${LB_NAME}" --output=text --query='LoadBalancers[*].LoadBalancerArn')
echo "*****************************************************************"
echo "Printing ELB ARN: $ELBARN"
echo "*****************************************************************"

echo "Waiting for ELB to become available..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ELBARN
echo "ELB is now available."

MYVPCID=$(aws ec2 describe-vpcs --output=text --query='Vpcs[*].VpcId')
echo "VPC ID: $MYVPCID"

echo "Creating target group '${TG_NAME}'..."
aws elbv2 create-target-group \
    --name "${TG_NAME}" \
    --protocol HTTP \
    --port 80 \
    --target-type instance \
    --vpc-id $MYVPCID

TGARN=$(aws elbv2 describe-target-groups --names "${TG_NAME}" --output=text --query='TargetGroups[*].TargetGroupArn')
echo "Target group ARN: $TGARN"

echo "Creating elbv2 listener..."
aws elbv2 create-listener --load-balancer-arn $ELBARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TGARN
echo "Created elbv2 listener."

echo "Creating auto-scaling group '${14}'..."
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name "${14}" \
    --launch-template LaunchTemplateName="${LAUNCH_TEMPLATE_NAME}" \
    --target-group-arns $TGARN \
    --health-check-type ELB \
    --health-check-grace-period 120 \
    --min-size "${16}" \
    --max-size "${17}" \
    --desired-capacity "${18}" \
    --tags Key=Name,Value="${EC2_NAME}"

# Tag EC2 Instances
EC2IDS=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=pending,running" \
    --output=text \
    --query='Reservations[*].Instances[*].InstanceId')

if [ -n "$EC2IDS" ]; then
    echo "Tagging EC2 instances with '${EC2_NAME}'..."
    aws ec2 create-tags --resources $EC2IDS --tags Key=Name,Value="${EC2_NAME}"
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
aws s3api create-bucket --bucket "${S3_BUCKET_RAW}" --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
aws s3api create-bucket --bucket "${S3_BUCKET_FINISHED}" --region us-east-2 --create-bucket-configuration LocationConstraint=us-east-2
echo "S3 buckets '${S3_BUCKET_RAW}' and '${S3_BUCKET_FINISHED}' created."

# Create RDS subnet group
echo "Creating RDS subnet group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name "${RDS_ID}-subnet-group" \
    --db-subnet-group-description "Subnet group for ${RDS_ID}" \
    --subnet-ids $SUBNET2A $SUBNET2B $SUBNET2C \
    --tags Key=Name,Value="${VPC_ID}"
echo "Created RDS subnet group '${RDS_ID}-subnet-group'."

# Create RDS instance from snapshot
echo "Creating RDS instance '${RDS_ID}' from snapshot 'module06fullschemasnapshot'..."
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier "${RDS_ID}" \
    --db-snapshot-identifier "module06fullschemasnapshot" \
    --vpc-security-group-ids sg-04d74d95a88ed4a91 \
    --db-subnet-group-name "${RDS_ID}-subnet-group" \
    --tags Key=Name,Value="${VPC_ID}"
echo "Created RDS instance '${RDS_ID}' from snapshot."

# Wait for the RDS instance to be available
echo "Waiting for RDS instance '${RDS_ID}' to become available..."
aws rds wait db-instance-available --db-instance-identifier "${RDS_ID}"
echo "RDS instance '${RDS_ID}' is now available."

echo "Printing DNS name of the load balancer..."
DNSNAME=$(aws elbv2 describe-load-balancers --names "${LB_NAME}" --output=text --query='LoadBalancers[*].DNSName')
echo "DNS URL: http://$DNSNAME"
