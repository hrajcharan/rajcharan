resource "aws_kms_key" "s3" {
  description         = "KMS for S3"
  enable_key_rotation = true
}
resource "aws_kms_key" "rds" { 
  description         = "KMS for RDS"
  enable_key_rotation = true
}

resource "aws_kms_key" "ebs" { 
  description         = "KMS for EBS"
  enable_key_rotation = true
}
resource "aws_ebs_encryption_by_default" "this" { enabled = true }
resource "aws_ebs_default_kms_key" "this" { key_arn = aws_kms_key.ebs.arn }

resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs-${data.aws_caller_identity.current.account_id}"
  tags = { Name = "${local.name_prefix}-logs" }
}
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "docs" {
  bucket              = "${local.name_prefix}-docs-${data.aws_caller_identity.current.account_id}"
  object_lock_enabled = true
  tags = { Name = "${local.name_prefix}-docs", Backup = "Yes" }
}
resource "aws_s3_bucket_public_access_block" "docs" {
  bucket = aws_s3_bucket.docs.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_logging" "docs" {
  bucket        = aws_s3_bucket.docs.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access/"
}
resource "aws_s3_bucket_lifecycle_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id
  rule {
    id     = "transition-and-retain"
    status = "Enabled"
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 1826
    }
  }
}
