resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-app-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t2.micro"
  iam_instance_profile { name = aws_iam_instance_profile.ec2_profile.name }
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -eux
    dnf -y update
    dnf -y install java-17-amazon-corretto amazon-cloudwatch-agent
    echo "GoGreen App – $(hostname) – ready" > /etc/motd
    mkdir -p /opt/aws/amazon-cloudwatch-agent/bin
    cat >/opt/aws/amazon-cloudwatch-agent/bin/config.json <<'JSON'
    ${local.cwagent_config}
    JSON
    systemctl enable amazon-cloudwatch-agent
    systemctl start amazon-cloudwatch-agent
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
      Name   = "app-tier"
      Role   = "app"
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

resource "aws_autoscaling_group" "app" {
  name                = "${local.name_prefix}-app-asg"
  desired_capacity    = 2
  max_size            = 5
  min_size            = 2
  vpc_zone_identifier = [for s in aws_subnet.private_app : s.id]
  launch_template { 
    id = aws_launch_template.app.id
     version = "$Latest" 
  }
  tag { 
    key="Name" 
    value="app-tier"
     propagate_at_launch=true 
    }
}

# CPU target tracking ~55%
resource "aws_autoscaling_policy" "app_cpu_tgt" {
  name                   = "${local.name_prefix}-app-cpu55"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app.name
  target_tracking_configuration {
    predefined_metric_specification { predefined_metric_type = "ASGAverageCPUUtilization" }
    target_value = 55
  }
}

# Step scaling policies used by memory alarms
resource "aws_autoscaling_policy" "app_scale_out" {
  name                   = "${local.name_prefix}-app-mem-scaleout"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "StepScaling"
  adjustment_type        = "ChangeInCapacity"
  metric_aggregation_type = "Average"
  step_adjustment { 
    scaling_adjustment = 1
     metric_interval_lower_bound = 0 
     }
}
resource "aws_autoscaling_policy" "app_scale_in" {
  name                   = "${local.name_prefix}-app-mem-scalein"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "StepScaling"
  adjustment_type        = "ChangeInCapacity"
  metric_aggregation_type = "Average"
  step_adjustment { 
    scaling_adjustment = -1
     metric_interval_upper_bound = 0 
     }
}
