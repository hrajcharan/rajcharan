import boto3
from tqdm import tqdm

# Initialize boto3 clients for EC2, ELB, and Auto Scaling
clientEC2 = boto3.client('ec2')
clientELB = boto3.client('elbv2')
clientASG = boto3.client('autoscaling')

grandtotal = 0
totalPoints = 5

# Function to print out current points progress
def currentPoints():
    print("Current Points: " + str(grandtotal) + " out of " + str(totalPoints) + ".")

# Function to read arguments from the 'arguments.txt' file
def read_arguments(file_path):
    with open(file_path, 'r') as file:
        args = file.read().splitlines()
    return args

# Check for the existence of zero Launch Templates
def check_launch_templates():
    try:
        response = clientEC2.describe_launch_templates()
        if not response['LaunchTemplates']:
            print("No Launch Templates exist.")
            return True
        else:
            print(f"Launch Templates exist: {len(response['LaunchTemplates'])}")
            return False
    except Exception as e:
        print(f"Error checking Launch Templates: {e}")
        return False

# Check for the existence of zero Auto Scaling Groups
def check_auto_scaling_groups():
    try:
        response = clientASG.describe_auto_scaling_groups()
        if not response['AutoScalingGroups']:
            print("No Auto Scaling Groups exist.")
            return True
        else:
            print(f"Auto Scaling Groups exist: {len(response['AutoScalingGroups'])}")
            return False
    except Exception as e:
        print(f"Error checking Auto Scaling Groups: {e}")
        return False

# Check for the existence of zero Elastic Load Balancers (ELBs)
def check_elbs():
    try:
        response = clientELB.describe_load_balancers()
        if not response['LoadBalancers']:
            print("No Elastic Load Balancers (ELBs) exist.")
            return True
        else:
            print(f"Elastic Load Balancers (ELBs) exist: {len(response['LoadBalancers'])}")
            return False
    except Exception as e:
        print(f"Error checking ELBs: {e}")
        return False

# Check for the existence of zero EC2 instances
def check_ec2_instances():
    try:
        response = clientEC2.describe_instances(Filters=[{'Name': 'instance-state-name', 'Values': ['pending', 'running']}])
        instances = [reservation['Instances'] for reservation in response['Reservations']]
        if not instances:
            print("No EC2 instances exist.")
            return True
        else:
            instance_count = sum([len(i) for i in instances])
            print(f"EC2 instances exist: {instance_count}")
            return False
    except Exception as e:
        print(f"Error checking EC2 instances: {e}")
        return False

# Check for the existence of zero Target Groups
def check_target_groups():
    try:
        response = clientELB.describe_target_groups()
        if not response['TargetGroups']:
            print("No Target Groups exist.")
            return True
        else:
            print(f"Target Groups exist: {len(response['TargetGroups'])}")
            return False
    except Exception as e:
        print(f"Error checking Target Groups: {e}")
        return False

# Read the arguments from the file 'arguments.txt'
args = read_arguments('arguments.txt')

# Begin Grading Process

# Test 1: Check Launch Templates
if check_launch_templates():
    grandtotal += 1
currentPoints()

# Test 2: Check Auto Scaling Groups
if check_auto_scaling_groups():
    grandtotal += 1
currentPoints()

# Test 3: Check ELBs
if check_elbs():
    grandtotal += 1
currentPoints()

# Test 4: Check EC2 instances
if check_ec2_instances():
    grandtotal += 1
currentPoints()

# Test 5: Check Target Groups
if check_target_groups():
    grandtotal += 1
currentPoints()

# Final Score
print(f"Final Score: {grandtotal} out of {totalPoints}")
