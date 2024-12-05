import boto3
from tqdm import tqdm
import requests
import time

# Initialize boto3 clients for EC2, ELB, RDS, and Secrets Manager
clientEC2 = boto3.client('ec2')
clientELB = boto3.client('elbv2')
clientRDS = boto3.client('rds')
clientSecrets = boto3.client('secretsmanager')

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

# Check for the existence of two RDS instances
def check_rds_instances(expected_count):
    try:
        response = clientRDS.describe_db_instances()
        instances = response['DBInstances']
        if len(instances) >= expected_count:
            print(f"Found {len(instances)} RDS instances.")
            return True
        else:
            print(f"Found only {len(instances)} RDS instances, expected at least {expected_count}.")
            return False
    except Exception as e:
        print(f"Error checking RDS instances: {e}")
        return False

# Check for the existence of the module-06 tag for RDS instance
def check_rds_tag(tag_key, tag_value):
    try:
        response = clientRDS.describe_db_instances()
        instances = response['DBInstances']
        tagged_instances = [db for db in instances if any(tag['Key'] == tag_key and tag['Value'] == tag_value for tag in db.get('TagList', []))]
        if tagged_instances:
            print(f"Found RDS instance with tag {tag_key}: {tag_value}")
            return True
        else:
            print(f"No RDS instance found with tag {tag_key}: {tag_value}")
            return False
    except Exception as e:
        print(f"Error checking RDS tags: {e}")
        return False

# Check for the existence of any Secrets in Secrets Manager
def check_any_secrets_exists():
    try:
        response = clientSecrets.list_secrets()
        secrets = response['SecretList']
        if secrets:
            print(f"Secrets exist in Secrets Manager: {len(secrets)} found.")
            return True
        else:
            print("No secrets found in Secrets Manager.")
            return False
    except Exception as e:
        print(f"Error checking Secrets Manager: {e}")
        return False

# Check for the existence of three EC2 instances tagged with module-06
def check_ec2_instances(tag_key, tag_value, expected_count):
    try:
        response = clientEC2.describe_instances(Filters=[{'Name': f'tag:{tag_key}', 'Values': [tag_value]}])
        instances = [instance for reservation in response['Reservations'] for instance in reservation['Instances']]
        if len(instances) >= expected_count:
            print(f"Found {len(instances)} EC2 instances with tag {tag_key}: {tag_value}.")
            return True
        else:
            print(f"Found only {len(instances)} EC2 instances with tag {tag_key}: {tag_value}, expected at least {expected_count}.")
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
args = read_arguments('arguments06.txt')

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
rds_db_name=args[18]

# Begin Grading Process

# Test 1: Check for the existence of RDS instance
if check_rds_instances(expected_count=1):
    grandtotal += 1
currentPoints()

# Test 2: Check for the existence of the module-08 tag for RDS instances
if check_rds_tag('Name', 'module-08'):
    grandtotal += 1
currentPoints()

# Test 3: Check for the existence of any secrets in Secrets Manager
if check_any_secrets_exists():
    grandtotal += 1
currentPoints()

# Test 4: Check for the existence of three EC2 instances tagged with module-06
if check_ec2_instances('Name', 'module-08', expected_count=3):
    grandtotal += 1
currentPoints()

# Test 5: Check ELB HTTP status
try:
    elb_response = clientELB.describe_load_balancers(Names=[elb_name])['LoadBalancers'][0]
    
    # Check the HTTP status of the ELB using its DNS name
    if check_http_status(elb_response['DNSName']):
        grandtotal += 1
        currentPoints()
except IndexError:
    print(f"Error: Load balancer '{elb_name}' not found.")
except Exception as e:
    print(f"Error retrieving ELB information: {e}")

# Final Score
print(f"Final Score: {grandtotal} out of {totalPoints}")
