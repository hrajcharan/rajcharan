# ------------------------
# Account-wide Password Policy
# ------------------------
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 8
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  max_password_age               = 90
  password_reuse_prevention      = 3
  allow_users_to_change_password = true
}

# ------------------------
# MFA Enforcement Policy
# ------------------------
data "aws_iam_policy_document" "mfa_enforce" {
  statement {
    sid    = "DenyIfNoMFA"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
      "iam:ResyncMFADevice",
      "iam:ChangePassword",
      "sts:GetSessionToken"
    ]
    resources = ["*"]
    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "mfa_enforce" {
  name   = "${local.name_prefix}-mfa-enforce"
  policy = data.aws_iam_policy_document.mfa_enforce.json
}

# ------------------------
# IAM Groups
# ------------------------
resource "aws_iam_group" "system_admins" {
  name = "${local.name_prefix}-system-admins"
}
resource "aws_iam_group" "db_admins" {
  name = "${local.name_prefix}-db-admins"
}
resource "aws_iam_group" "monitoring" {
  name = "${local.name_prefix}-monitoring"
}

# ------------------------
# Group Policy Attachments
# ------------------------
# System Admins
resource "aws_iam_group_policy_attachment" "sysadmin_admin" {
  group      = aws_iam_group.system_admins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
resource "aws_iam_group_policy_attachment" "sysadmin_mfa" {
  group      = aws_iam_group.system_admins.name
  policy_arn = aws_iam_policy.mfa_enforce.arn
}

# DB Admins
resource "aws_iam_group_policy_attachment" "dbadmin_rds" {
  group      = aws_iam_group.db_admins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}
resource "aws_iam_group_policy_attachment" "dbadmin_backup" {
  group      = aws_iam_group.db_admins.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupFullAccess"
}
resource "aws_iam_group_policy_attachment" "dbadmin_mfa" {
  group      = aws_iam_group.db_admins.name
  policy_arn = aws_iam_policy.mfa_enforce.arn
}

# Monitoring
resource "aws_iam_group_policy_attachment" "monitor_ro" {
  group      = aws_iam_group.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}
resource "aws_iam_group_policy_attachment" "monitor_mfa" {
  group      = aws_iam_group.monitoring.name
  policy_arn = aws_iam_policy.mfa_enforce.arn
}

# ------------------------
# IAM Users + Group Memberships
# ------------------------
# System Admins
resource "aws_iam_user" "sysadmins" {
  for_each      = toset(["sysadmin1","sysadmin2"])
  name          = "${local.name_prefix}-${each.key}"
  force_destroy = true
  tags          = { Group = "system-admins" }
}
resource "aws_iam_user_group_membership" "sysadmins" {
  for_each = aws_iam_user.sysadmins
  user     = each.value.name
  groups   = [aws_iam_group.system_admins.name]
}

# DB Admins
resource "aws_iam_user" "dbadmins" {
  for_each      = toset(["dbadmin1","dbadmin2"])
  name          = "${local.name_prefix}-${each.key}"
  force_destroy = true
  tags          = { Group = "db-admins" }
}
resource "aws_iam_user_group_membership" "dbadmins" {
  for_each = aws_iam_user.dbadmins
  user     = each.value.name
  groups   = [aws_iam_group.db_admins.name]
}

# Monitors
resource "aws_iam_user" "monitors" {
  for_each      = toset(["monitor1","monitor2","monitor3","monitor4"])
  name          = "${local.name_prefix}-${each.key}"
  force_destroy = true
  tags          = { Group = "monitoring" }
}
resource "aws_iam_user_group_membership" "monitors" {
  for_each = aws_iam_user.monitors
  user     = each.value.name
  groups   = [aws_iam_group.monitoring.name]
}

# ------------------------
# Random Passwords + Login Profiles
# ------------------------
resource "random_password" "user_pw" {
  for_each = merge(
    aws_iam_user.sysadmins,
    aws_iam_user.dbadmins,
    aws_iam_user.monitors
  )
  length  = 20
  special = true
}

resource "aws_iam_user_login_profile" "users" {
  for_each                = random_password.user_pw
  user                    = each.key
  password_reset_required = true
}

# Output initial passwords securely
output "iam_user_passwords" {
  description = "Initial IAM user passwords (reset required at first login)"
  sensitive   = true
  value = {
    for username, pw in random_password.user_pw : username => pw.result
  }
}

# ------------------------
# EC2 Instance Role (S3 + CloudWatch Agent)
# ------------------------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

data "aws_iam_policy_document" "ec2_policy" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.docs.arn, "${aws_s3_bucket.docs.arn}/*"]
  }
  statement {
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.s3.arn]
  }
}

resource "aws_iam_policy" "ec2_policy" {
  name   = "${local.name_prefix}-ec2-s3-cw"
  policy = data.aws_iam_policy_document.ec2_policy.json
}

resource "aws_iam_role_policy_attachment" "ec2_custom" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_iam_role_policy_attachment" "ec2_cwagent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
