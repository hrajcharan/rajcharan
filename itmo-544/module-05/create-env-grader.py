import boto3
from tqdm import tqdm
import requests
import time

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

# Check for the existence of one Launch Template
def check_launch_template(template_name):
    try:
        response = clientEC2.describe_launch_templates(LaunchTemplateNames=[template_name])
        if response['LaunchTemplates']:
            print(f"Launch Template {template_name} exists.")
            return True
        else:
            print(f"Launch Template {template_name} does not exist.")
            return False
    except Exception as e:
        print(f"Error checking Launch Template: {e}")
        return False

# Check for the existence of one Autoscaling Group
def check_asg(asg_name):
    try:
        response = clientASG.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])
        if response['AutoScalingGroups']:
            print(f"Autoscaling Group {asg_name} exists.")
            return True
        else:
            print(f"Autoscaling Group {asg_name} does not exist.")
            return False
    except Exception as e:
        print(f"Error checking Autoscaling Group: {e}")
        return False

# Check for the existence of ELB
def check_elb(elb_name):
    try:
        response = clientELB.describe_load_balancers(Names=[elb_name])
        if response['LoadBalancers']:
            print(f"ELB {elb_name} exists.")
            return response['LoadBalancers'][0]
        else:
            print(f"ELB {elb_name} does not exist.")
            return None
    except Exception as e:
        print(f"Error checking ELB: {e}")
        return None

# Check if EC2 instances are tagged with 'module-05'
def check_ec2_instances(tag_key, tag_value):
    try:
        response = clientEC2.describe_instances(Filters=[{'Name': f'tag:{tag_key}', 'Values': [tag_value]}])
        instances = response['Reservations']
        if instances:
            print(f"Found EC2 instances with tag {tag_key}: {tag_value}")
            return True
        else:
            print(f"No EC2 instances found with tag {tag_key}: {tag_value}")
            return False
    except Exception as e:
        print(f"Error checking EC2 instances: {e}")
        return False

# Check HTTP status of ELB URL
def check_http_status(dns_name):
    print(f"Checking HTTP status of ELB: http://{dns_name}")
    for _ in tqdm(range(30)):  # Delay loop for the server to be ready
        time.sleep(1)
    try:
        res = requests.get(f"http://{dns_name}")
        if res.status_code == 200:
            print(f"Successful HTTP request to {dns_name}")
            return True
        else:
            print(f"Incorrect HTTP status: {res.status_code} from {dns_name}")
            return False
    except requests.exceptions.ConnectionError as errc:
        print(f"Error Connecting: {errc}")
        return False

# Read the arguments from the file 'arguments.txt'
args = read_arguments('arguments.txt')

# Mapping file arguments to respective variables
ami_id = args[0]
instance_type = args[1]
key_name = args[2]
security_group_id = args[3]
instance_count = args[4]
user_data = args[5]
availability_zone = args[6]
elb_name = args[7]
target_group_name = args[8]
availability_zone_a = args[9]
availability_zone_b = args[10]
availability_zone_c = args[11]
tag_value = args[12]
asg_name = args[13]
launch_template_name = args[14]
asg_min = args[15]
asg_max = args[16]
asg_desired = args[17]

# Begin Grading Process

# Test 1: Check Launch Template
if check_launch_template(launch_template_name):
    grandtotal += 1
currentPoints()

# Test 2: Check Autoscaling Group
if check_asg(asg_name):
    grandtotal += 1
currentPoints()

# Test 3: Check ELB existence
elb_response = check_elb(elb_name)
if elb_response:
    grandtotal += 1
currentPoints()

# Test 4: Check EC2 instances with the specified tag value (module-05)
if check_ec2_instances('Name', tag_value):
    grandtotal += 1
currentPoints()

# Test 5: Check ELB HTTP status
if elb_response and check_http_status(elb_response['DNSName']):
    grandtotal += 1
currentPoints()

# Final Score
print(f"Final Score: {grandtotal} out of {totalPoints}")
