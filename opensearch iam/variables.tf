variable "role_name" {
  description = "Name of the IAM role that will access the OpenSearch domain."
  type        = string
}

variable "domain_arn" {
  description = "ARN of the OpenSearch domain, e.g., arn:aws:es:us-east-1:111122223333:domain/my-os-domain"
  type        = string
}

variable "http_actions" {
  description = "Allowed HTTP-style actions for OpenSearch."
  type        = list(string)
  default     = ["es:ESHttpGet", "es:ESHttpPost", "es:ESHttpPut", "es:ESHttpDelete", "es:ESHttpHead"]
}

variable "trusted_services" {
  description = "AWS services allowed to assume the role (e.g., ec2.amazonaws.com). Mutually exclusive with trusted_principals."
  type        = list(string)
  default     = []
}

variable "trusted_principals" {
  description = "Exact AWS principals (roles/users/ARNS) allowed to assume the role. Mutually exclusive with trusted_services."
  type        = list(string)
  default     = []
}

variable "role_path" {
  description = "Path for IAM role."
  type        = string
  default     = "/"
}

variable "role_tags" {
  description = "Tags to apply to the role."
  type        = map(string)
  default     = {}
}

variable "domain_policy_additional_statements" {
  description = "Optional extra statements to merge into the domain resource policy."
  type        = list(any)
  default     = []
}

variable "attach_readonly_policy" {
  description = "If true, limit to read-only (GET/HEAD) regardless of http_actions input."
  type        = bool
  default     = false
}
