locals {
  domain_resource_arns = [
    var.domain_arn,
    "${var.domain_arn}/*"
  ]

  readonly_actions = ["es:ESHttpGet", "es:ESHttpHead"]

  effective_actions = var.attach_readonly_policy ? local.readonly_actions : var.http_actions

  assume_role_principal = length(var.trusted_services) > 0 ? {
    Service = var.trusted_services
  } : (
    length(var.trusted_principals) > 0 ? {
      AWS = var.trusted_principals
    } : {}
  )

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = local.assume_role_principal
        Action    = "sts:AssumeRole"
      }
    ]
  })

  inline_policy_doc = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid      = "OpenSearchHttpAccess"
        Effect   = "Allow"
        Action   = local.effective_actions
        Resource = local.domain_resource_arns
      }
    ]
  })
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  path               = var.role_path
  assume_role_policy = local.assume_role_policy
  tags               = var.role_tags
}

resource "aws_iam_role_policy" "opensearch_http" {
  name   = "${var.role_name}-opensearch-http"
  role   = aws_iam_role.this.id
  policy = local.inline_policy_doc
}

data "aws_iam_policy_document" "domain_base" {
  statement {
    sid     = "AllowRoleAccessToDomain"
    effect  = "Allow"
    actions = ["es:*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.this.arn]
    }

    resources = local.domain_resource_arns
  }
}

data "aws_iam_policy_document" "domain_full" {
  source_json = data.aws_iam_policy_document.domain_base.json

  dynamic "statement" {
    for_each = var.domain_policy_additional_statements
    content {
      sid       = lookup(statement.value, "sid", null)
      effect    = lookup(statement.value, "effect", "Allow")
      actions   = lookup(statement.value, "actions", [])
      resources = lookup(statement.value, "resources", local.domain_resource_arns)

      dynamic "principals" {
        for_each = lookup(statement.value, "principals", [])
        content {
          type        = lookup(principals.value, "type", "AWS")
          identifiers = lookup(principals.value, "identifiers", [])
        }
      }

      dynamic "condition" {
        for_each = lookup(statement.value, "condition", {})
        content {
          test     = condition.key
          variable = lookup(condition.value, "variable", null)
          values   = lookup(condition.value, "values", [])
        }
      }
    }
  }
}

resource "aws_opensearch_domain_policy" "this" {
  domain_name     = split("/", replace(var.domain_arn, "arn:aws:es:", ""))[1]
  access_policies = data.aws_iam_policy_document.domain_full.json
}
