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
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $ASGNAME
echo "$ASGNAME autoscaling group was deleted!"

# Retrieve and delete the launch template
LTNAME=$(aws ec2 describe-launch-templates --output=text --query='LaunchTemplates[*].LaunchTemplateName')
echo "*****************************************************************"
echo "Launch template name: $LTNAME"
echo "*****************************************************************"
aws ec2 delete-launch-template --launch-template-name "$LTNAME"
echo "$LTNAME launch template was deleted!"