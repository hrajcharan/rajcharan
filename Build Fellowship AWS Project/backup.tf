data "aws_iam_policy_document" "backup_trust" {
  statement {
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "backup" {
  name               = "${local.name_prefix}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_trust.json
}
resource "aws_iam_role_policy_attachment" "backup_attach1" { 
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
resource "aws_iam_role_policy_attachment" "backup_attach2" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_vault" "vault" { name = "${local.name_prefix}-backup-vault" }

resource "aws_backup_plan" "plan" {
  name = "${local.name_prefix}-backup-plan"
  rule {
    rule_name         = "every-4h"
    target_vault_name = aws_backup_vault.vault.name
    schedule          = "cron(0 0/4 * * ? *)"
    lifecycle { delete_after = 35 }
  }
}

resource "aws_backup_selection" "selection_tags" {
  name     = "${local.name_prefix}-backup-selection-tags"
  plan_id  = aws_backup_plan.plan.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "Yes"
  }
}

resource "aws_backup_selection" "selection_rds" {
  name           = "${local.name_prefix}-backup-selection-rds"
  plan_id = aws_backup_plan.plan.id
  iam_role_arn   = aws_iam_role.backup.arn
  resources      = [aws_db_instance.db.arn]
}
