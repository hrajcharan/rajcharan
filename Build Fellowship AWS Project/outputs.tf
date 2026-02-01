output "cloudfront_domain" { value = aws_cloudfront_distribution.main.domain_name }
output "alb_dns_name"      { value = aws_lb.alb.dns_name }
output "rds_endpoint"      { value = aws_db_instance.db.address }
output "s3_docs_bucket"    { value = aws_s3_bucket.docs.bucket }

output "created_iam_users_initial_passwords" {
  value = { for u, prof in aws_iam_user_login_profile.users : u => prof.password }
  sensitive = true
}
