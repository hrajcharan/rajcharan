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

ELBARN=$(aws elbv2 describe-load-balancers
