resource "aws_db_subnet_group" "db" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = [for s in aws_subnet.private_db : s.id]
}

resource "aws_db_parameter_group" "mysql" {
  name   = "${local.name_prefix}-mysql8-params"
  family = "mysql8.0"
  description = "MySQL 8 param group"
}

resource "aws_db_instance" "db" {
  identifier              = "${var.project_name}-mysql"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.m5.large"
  allocated_storage       = 100
  storage_type            = "io1"
  iops                    = 21000
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.rds.arn
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.db.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  multi_az                = true
  backup_retention_period = 7
  skip_final_snapshot     = true
  apply_immediately       = true
  parameter_group_name    = aws_db_parameter_group.mysql.name
  deletion_protection     = false
  tags = { Name = "${local.name_prefix}-rds" }
}
