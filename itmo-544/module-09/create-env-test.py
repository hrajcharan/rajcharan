import boto3
from tqdm import tqdm
import requests
import time

# Initialize boto3 clients for EC2, ELB, RDS, S3, SNS, and Secrets Manager
clientEC2 = boto3.client('ec2')
clientELB = boto3.client('elbv2')
clientRDS = boto3.client('rds')
clientSecrets = boto3.client('secretsmanager')
clientS3 = boto3.client('s3')
clientSNS = boto3.client('sns')

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

# Check for the existence of one SNS Topic
def check_sns_topic(expected_count):
    try:
        response = clientSNS.list_topics()
        topics = response['Topics']
        if len(topics) >= expected_count:
            print(f"Found {len(topics)} SNS topic(s).")
            return True
        else:
            print(f"Found only {len(topics)} SNS topic(s), expected at least {expected_count}.")
            return False
    except Exception as e:
        print(f"Error checking SNS topics: {e}")
        return False

# Check for the existence of one RDS instance
def check_rds_instances(expected_count):
    try:
        response = clientRDS.describe_db_instances()
        instances = response['DBInstances']
        if len(instances) == expected_count:
            print(f"Found {len(instances)} RDS instance(s).")
            return True
        else:
            print(f"Found {len(instances)} RDS instance(s), expected {expected_count}.")
            return False
    except Exception as e:
        print(f"Error checking RDS instances: {e}")
        return False

# Check for the existence of the module-09 tag for the RDS instance
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

# Check for the existence of two S3 buckets
def check_s3_buckets(expected_count):
    try:
        response = clientS3.list_buckets()
        buckets = response['Buckets']
        if len(buckets) >= expected_count:
            print(f"Found {len(buckets)} S3 bucket(s).")
            return True
        else:
            print(f"Found only {len(buckets)} S3 buckets, expected at least {expected_count}.")
            return False
    except Exception as e:
        print(f"Error checking S3 buckets: {e}")
        return False

# Check for specific files in the S3 bucket
def check_s3_files(bucket_name, file_names):
    try:
        for file_name in file_names:
            response = clientS3.head_object(Bucket=bucket_name, Key=file_name)
            print(f"Found file: {file_name} in bucket {bucket_name}.")
        return True
    except Exception as e:
        print(f"Error checking files in bucket {bucket_name}: {e}")
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
rds_db_name = args[18]
IAM_Instance_Profile_Name=args[19]
S3_Bucket_Raw=args[20]
S3_Bucket_Finished=args[21]
sns_topic=args[22]

# Begin Grading Process

# Test 1: Check for the existence of one SNS Topic
if check_sns_topic(expected_count=1):
    grandtotal += 1
currentPoints()

# Test 2: Check for the existence of the module-09 tag for the RDS instance
if check_rds_tag('Name', 'module-09'):
    grandtotal += 1
currentPoints()

# Test 3: Check for the existence of two S3 buckets and specific files
if check_s3_buckets(expected_count=2):
    grandtotal += 1
currentPoints()

# Test 4: Check for specific files in the raw S3 bucket
if check_s3_files(S3_Bucket_Raw, ['vegeta.jpg', 'knuth.jpg']):
    grandtotal += 1  # S3 Files exist
currentPoints()

# Test 5: Check ELB HTTP status
try:
    elb_response = clientELB.describe_load_balancers(Names=[elb_name])['LoadBalancers'][0]
    if check_http_status(elb_response['DNSName']):
        grandtotal += 1
        currentPoints()
except IndexError:
    print(f"Error: Load balancer '{elb_name}' not found.")
except Exception as e:
    print(f"Error retrieving ELB information: {e}")

# Final Score
print(f"Final Score: {grandtotal} out of {totalPoints}")
