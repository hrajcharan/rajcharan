terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.50" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
    http = { source = "hashicorp/http", version = "~> 3.4" }
  }
}

provider "aws" { region = var.region }
provider "http" {}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }
data "http" "my_ip" { url = "https://checkip.amazonaws.com" }

locals {
  azs            = slice(data.aws_availability_zones.available.names, 0, 2)
  name_prefix    = "${var.project_name}-${var.region}"
  caller_ip_cidr = var.my_ip != "" ? var.my_ip : "${chomp(data.http.my_ip.response_body)}/32"

  cwagent_config = jsonencode({
    metrics = {
      namespace = "CWAgent"
      append_dimensions = { AutoScalingGroupName = "${"$"}{aws:AutoScalingGroupName}" }
      metrics_collected = {
        mem  = { measurement = ["mem_used_percent"] }
        disk = { resources = ["*"], measurement = ["used_percent"] }
      }
    }
    logs = {
      logs_collected = { files = { collect_list = [
        { file_path = "/var/log/messages", log_group_name = "/gogreen/system", log_stream_name = "{instance_id}" }
      ]}}
    }
  })
}
