# GoGreen Insurance – AWS Terraform (Updated)

This repo deploys a 3‑tier architecture meeting the GoGreen requirements:
- VPC with public/private subnets across 2 AZs, NAT,routing
- Web tier (ASG, private) behind ALB
- App tier (ASG, private) with NAT for patching
- RDS MySQL (Multi‑AZ, **io1 21,000 IOPS** for consistent performance)
- S3 documents bucket (KMS, versioning, **Object Lock**, 90‑day transition to IA, **5‑year retention**)
- CloudFront in front of **ALB** and **S3 /docs/**
- IAM password policy, groups, MFA enforcement; EC2 role (S3 + CW)
- CloudWatch alarms: ALB 4xx>100/min, CPU high/low, **memory‑based scaling** (CW Agent)
- AWS Backup vault & plan: **every 4 hours** (RPO ≤ 4h), tag‑based EC2 + explicit RDS selection

## Usage
```bash
terraform init
terraform apply   -var='region=eu-west-1'   -var='db_password=ChangeMeStrong123!'   -var='alert_emails=["you@example.com"]'   -auto-approve
```
> ⚠️ DB with 21k IOPS and Multi‑AZ incurs cost. For classroom tests, switch to gp3 and smaller class.

## Key outputs
- `cloudfront_domain` – primary global entry point
- `alb_dns_name` – ALB endpoint (bypasses edge caching)
- `rds_endpoint` – MySQL endpoint
- `s3_docs_bucket` – docs bucket name

## Requirement Trace
- **Scalability**: ASG + target tracking (CPU ~55%) and step scaling on memory (30–80% bounds)
- **Stateless web**: web tier AMI with simple httpd; state goes to S3/RDS
- **RPO ≤ 4h**: AWS Backup plan `cron(0 0/4 * * ? *)`
- **5‑year retention**: S3 Object Lock(Compliance) + lifecycle expire after 1826 days; transition to IA after 90 days
- **21k IOPS DB**: RDS `io1 iops=21000`, Multi‑AZ
- **Encryption**: KMS for EBS/RDS/S3; TLS at CloudFront (default cert) – you can attach ACM for custom domain
- **Security**: password policy + MFA deny‑without‑MFA; SGs isolate tiers; app patching via NAT (no public IPs)
- **Monitoring**: ALB 4xx>100/min; CPU high/low; memory alarms -> ASG scale in/out
