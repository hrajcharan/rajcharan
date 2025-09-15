#!/bin/bash

# Find the auto scaling group
echo "Retrieving autoscaling group name..."
ASGNAME=$(aws autoscaling describe-auto-scaling-groups --output=text --query='AutoScalingGroups[*].AutoScalingGroupName')
echo "*****************************************************************"
echo "Autoscaling group name: $ASGNAME"
echo "*****************************************************************"

# Update the auto scaling group to set minimum and desired capacity to 0
echo "Updating $ASGNAME autoscaling group to set minimum and desired capacity to 0..."
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name $ASGNAME \
    --health-check-type ELB \
    --min-size 0 \
    --desired-capacity 0
echo "$ASGNAME autoscaling group was updated!"

# Collect EC2 instance IDs
EC2IDS=$(aws ec2 describe-instances \
    --output=text \
    --query='Reservations[*].Instances[*].InstanceId' \
    --filter Name=instance-state-name,Values=pending,running)

echo "Waiting for instances..."
aws ec2 wait instance-terminated --instance-ids $EC2IDS
echo "Instances are terminated!"

# Retrieve the Target Group ARN
TGARN=$(aws elbv2 describe-target-groups --output=text --query='TargetGroups[*].TargetGroupArn')
echo "Target Group ARN: $TGARN"

# Retrieve Load Balancer and Listener ARN
ELBARN=$(aws elbv2 describe-load-balancers --output=text --query='LoadBalancers[*].LoadBalancerArn')
echo "Load Balancer ARN: $ELBARN"

LISTARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ELBARN" --output=text --query='Listeners[*].ListenerArn')

# Delete the ELB Listener
echo "Deleting listener with ARN: $LISTARN"
aws elbv2 delete-listener --listener-arn "$LISTARN"

# Delete the Target Group
echo "Deleting target group with ARN: $TGARN"
aws elbv2 delete-target-group --target-group-arn "$TGARN"

# Delete the load balancer
echo "*****************************************************************"
echo "Deleting Load Balancer: $ELBARN"
echo "*****************************************************************"
aws elbv2 delete-load-balancer --load-balancer-arn $ELBARN
aws elbv2 wait load-balancers-deleted --load-balancer-arns $ELBARN
echo "Load balancers deleted!"

# Delete the auto-scaling group
echo "Deleting $ASGNAME autoscaling group..."
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $ASGNAME --force-delete
echo "$ASGNAME autoscaling group was deleted!"

# Retrieve and delete the launch template
LTNAME=$(aws ec2 describe-launch-templates --output=text --query='LaunchTemplates[*].LaunchTemplateName')
echo "*****************************************************************"
echo "Launch template name: $LTNAME"
echo "*****************************************************************"
aws ec2 delete-launch-template --launch-template-name "$LTNAME"
echo "$LTNAME launch template was deleted!"


# Delete RDS instances
echo "Deleting RDS instances..."
RDSINSTANCES=$(aws rds describe-db-instances --output=text --query='DBInstances[*].DBInstanceIdentifier')
for DB_INSTANCE in $RDSINSTANCES; do
    aws rds delete-db-instance --db-instance-identifier "$DB_INSTANCE" --skip-final-snapshot
    aws rds wait db-instance-deleted --db-instance-identifier "$DB_INSTANCE"
done


# Retrieve and delete RDS subnet group
RDS_SUBNET_GROUP_NAMES=$(aws rds describe-db-subnet-groups --output=text --query='DBSubnetGroups[*].DBSubnetGroupName' | tr -d '\r' | awk '{$1=$1;print}')

if [ -n "$RDS_SUBNET_GROUP_NAMES" ]; then
    echo "Found RDS subnet groups: $RDS_SUBNET_GROUP_NAMES"
    for SUBNET_GROUP in $RDS_SUBNET_GROUP_NAMES; do
        echo "Attempting to delete RDS subnet group: $SUBNET_GROUP..."
        aws rds delete-db-subnet-group --db-subnet-group-name "$SUBNET_GROUP"
        if [ $? -eq 0 ]; then
            echo "RDS subnet group deleted: $SUBNET_GROUP"
        else
            echo "Failed to delete RDS subnet group: $SUBNET_GROUP"
        fi
    done
else
    echo "No RDS subnet groups found to delete."
fi





# Delete SNS subscriptions and topics
echo "Unsubscribing and deleting SNS topics..."
SNSTOPICS=$(aws sns list-topics --query='Topics[*].TopicArn' --output=text)
if [ -n "$SNSTOPICS" ]; then
    for TOPIC in $SNSTOPICS; do
        echo "Processing SNS topic: $TOPIC"
        SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC" --query='Subscriptions[*].SubscriptionArn' --output=text)
        if [ -n "$SUBSCRIPTIONS" ]; then
            for SUB in $SUBSCRIPTIONS; do
                if [ "$SUB" != "PendingConfirmation" ]; then
                    echo "Unsubscribing: $SUB"
                    aws sns unsubscribe --subscription-arn "$SUB"
                fi
            done
        fi
        echo "Deleting SNS topic: $TOPIC"
        aws sns delete-topic --topic-arn "$TOPIC"
    done
else
    echo "No SNS topics found."
fi

# Delete S3 buckets and contents
echo "Deleting S3 buckets and their contents..."
MYS3BUCKETS=$(aws s3api list-buckets --query "Buckets[*].Name" --output=text)
MYS3BUCKETS_ARRAY=($MYS3BUCKETS)

for j in "${MYS3BUCKETS_ARRAY[@]}"; do
    echo "Processing bucket: $j"
    MYKEYS=$(aws s3api list-objects --bucket "$j" --query 'Contents[*].Key' --output=text)
    MYKEYS_ARRAY=($MYKEYS)
    for k in "${MYKEYS_ARRAY[@]}"; do
        aws s3api delete-object --bucket "$j" --key "$k"
        aws s3api wait object-not-exists --bucket "$j" --key "$k"
    done
    aws s3api delete-bucket --bucket "$j" --region us-east-1
    aws s3api wait bucket-not-exists --bucket "$j"
    echo "Bucket $j deleted."
done
echo "All S3 buckets deleted!"