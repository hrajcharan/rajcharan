output "role_name" {
  value = aws_iam_role.this.name
}

output "role_arn" {
  value = aws_iam_role.this.arn
}

output "domain_policy_json" {
  description = "The computed domain resource policy JSON."
  value       = data.aws_iam_policy_document.domain_full.json
}
