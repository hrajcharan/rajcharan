# --- Amazon Linux 2023 AMI ---
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# --- Launch Template for Web Tier ---
resource "aws_launch_template" "web" {
  name_prefix   = "web-lt-"
  instance_type = "t2.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -eux
    dnf -y update
    dnf -y install httpd amazon-cloudwatch-agent
    echo "GoGreen Web – $(hostname) – healthy" > /var/www/html/index.html
    mkdir -p /opt/aws/amazon-cloudwatch-agent/bin
    cat >/opt/aws/amazon-cloudwatch-agent/bin/config.json <<'JSON'
    ${local.cwagent_config}
    JSON
    systemctl enable httpd
    systemctl start httpd
  EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.ebs.arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name   = "web-tier"
      Role   = "web"
      Backup = "Yes"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Backup = "Yes"
    }
  }
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "web" {
  name                = "${local.name_prefix}-web-asg"
  desired_capacity    = 2
  min_size            = 1
  max_size            = 5

  # Collect all subnet IDs from the for_each map
  vpc_zone_identifier = [for s in aws_subnet.public : s.id]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "web-asg"
    propagate_at_launch = true
  }
}


# --- Auto Scaling Policies ---

# CPU Target Tracking ~55%
resource "aws_autoscaling_policy" "web_cpu_tgt" {
  name                   = "${local.name_prefix}-web-cpu55"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.web.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 55
  }
}

# Step scaling scale-out
resource "aws_autoscaling_policy" "web_scale_out" {
  name                   = "${local.name_prefix}-web-mem-scaleout"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "StepScaling"
  adjustment_type        = "ChangeInCapacity"
  metric_aggregation_type = "Average"

  step_adjustment {
    scaling_adjustment          = 1
    metric_interval_lower_bound = 0
  }
}

# Step scaling scale-in
resource "aws_autoscaling_policy" "web_scale_in" {
  name                   = "${local.name_prefix}-web-mem-scalein"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "StepScaling"
  adjustment_type        = "ChangeInCapacity"
  metric_aggregation_type = "Average"

  step_adjustment {
    scaling_adjustment          = -1
    metric_interval_upper_bound = 0
  }
}
