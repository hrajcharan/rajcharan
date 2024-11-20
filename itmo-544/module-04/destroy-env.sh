#!/bin/bash

# First, describe EC2 instances
EC2IDS=$(aws ec2 describe-instances \
    --output=text \
    --query='Reservations[*].Instances[*].InstanceId' --filter Name=instance-state-name,Values=pending,running)

# Deregistering attached EC2 IDs before terminating instances
TGARN=$(aws elbv2 describe-target-groups --output=text --query='TargetGroups[*].TargetGroupArn')
echo "TGARN: $TGARN"

declare -a IDSARRAY
IDSARRAY=($EC2IDS)

# Deregister targets from the target group
for ID in "${IDSARRAY[@]}"; do
  echo "Now deregistering ID: $ID..."
  aws elbv2 deregister-targets \
    --target-group-arn "$TGARN" --targets Id="$ID"
  aws elbv2 wait target-deregistered --target-group-arn "$TGARN" --targets Id="$ID",Port=80
  echo "Target $ID deregistered."
done

# Delete listeners before attempting to delete the target group
ELBARN=$(aws elbv2 describe-load-balancers --output=text --query='LoadBalancers[*].LoadBalancerArn')
LISTARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ELBARN" --output=text --query='Listeners[*].ListenerArn')

# Delete listener if it exists
if [ -n "$LISTARN" ]; then
  echo "Deleting listener with ARN: $LISTARN"
  aws elbv2 delete-listener --listener-arn "$LISTARN"
  echo "Listener deleted."
else
  echo "No listeners found."
fi

# Now, delete the target group after the listener is gone
echo "Attempting to delete the target group..."
aws elbv2 delete-target-group --target-group-arn "$TGARN" || echo "Error deleting target group: Resource may still be in use."

# Now terminate all EC2 instances
aws ec2 terminate-instances --instance-ids $EC2IDS
aws ec2 wait instance-terminated --instance-ids $EC2IDS
echo "Instances are terminated!"

# Delete the load balancer
echo "*****************************************************************"
echo "Printing ELBARN: $ELBARN"
echo "*****************************************************************"

# Attempt to delete the load balancer
aws elbv2 delete-load-balancer --load-balancer-arn "$ELBARN" || echo "Error deleting load balancer: It may not exist."
aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ELBARN" || echo "Error waiting for load balancer to be deleted."
echo "Load balancers deleted!"
