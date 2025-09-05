resource "aws_cloudwatch_log_group" "system" {
  name              = "/gogreen/system"
  retention_in_days = 30
}

resource "aws_sns_topic" "alerts" { name = "${local.name_prefix}-alerts" }
resource "aws_sns_topic_subscription" "emails" {
  for_each  = toset(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "alb_4xx_burst" {
  alarm_name          = "${local.name_prefix}-alb-4xx-burst"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "More than 100 HTTP 4xx per minute on ALB targets"
  dimensions          = { LoadBalancer = aws_lb.alb.arn_suffix }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# CPU bounds informational alarms (optional; scaling handled by target tracking)
resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name           = "web-cpu-high"
  comparison_operator  = "GreaterThanThreshold"
  threshold            = 80
  evaluation_periods   = 2
  period               = 60
  statistic            = "Average"
  metric_name          = "CPUUtilization"
  namespace            = "AWS/EC2"
  dimensions           = { AutoScalingGroupName = aws_autoscaling_group.web.name }
  alarm_actions        = [aws_sns_topic.alerts.arn]
  ok_actions           = [aws_sns_topic.alerts.arn]
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_low" {
  alarm_name           = "web-cpu-low"
  comparison_operator  = "LessThanThreshold"
  threshold            = 30
  evaluation_periods   = 2
  period               = 60
  statistic            = "Average"
  metric_name          = "CPUUtilization"
  namespace            = "AWS/EC2"
  dimensions           = { AutoScalingGroupName = aws_autoscaling_group.web.name }
  alarm_actions        = [aws_sns_topic.alerts.arn]
  ok_actions           = [aws_sns_topic.alerts.arn]
}
resource "aws_cloudwatch_metric_alarm" "app_cpu_high" {
  alarm_name           = "app-cpu-high"
  comparison_operator  = "GreaterThanThreshold"
  threshold            = 80
  evaluation_periods   = 2
  period               = 60
  statistic            = "Average"
  metric_name          = "CPUUtilization"
  namespace            = "AWS/EC2"
  dimensions           = { AutoScalingGroupName = aws_autoscaling_group.app.name }
  alarm_actions        = [aws_sns_topic.alerts.arn]
  ok_actions           = [aws_sns_topic.alerts.arn]
}
resource "aws_cloudwatch_metric_alarm" "app_cpu_low" {
  alarm_name           = "app-cpu-low"
  comparison_operator  = "LessThanThreshold"
  threshold            = 30
  evaluation_periods   = 2
  period               = 60
  statistic            = "Average"
  metric_name          = "CPUUtilization"
  namespace            = "AWS/EC2"
  dimensions           = { AutoScalingGroupName = aws_autoscaling_group.app.name }
  alarm_actions        = [aws_sns_topic.alerts.arn]
  ok_actions           = [aws_sns_topic.alerts.arn]
}

# Memory alarms connected to step scaling
resource "aws_cloudwatch_metric_alarm" "web_mem_high" {
  alarm_name           = "web-mem-high"
  metric_name          = "mem_used_percent"
  namespace            = "CWAgent"
  comparison_operator  = "GreaterThanThreshold"
  threshold            = 80
  evaluation_periods   = 2
  period               = 60
  statistic            = "Average"
  dimensions           = { AutoScalingGroupName = aws_autoscaling_group.web.name }
  alarm_actions        = [aws_autoscaling_policy.web_scale_out.arn]
}
resource "aws_cloudwatch_metric_alarm" "web_mem_low" {
  alarm_name           = "web-mem-low"
  metric_name          = "mem_used_percent"
  namespace            = "CWAgent"
  comparison_operator  = "LessThanThreshold"
  threshold            = 30
  evaluation_periods   = 2
  period               = 60
  statistic            = "Average"
  dimensions           = { AutoScalingGroupName = aws_autoscaling_group.web.name }
  alarm_actions        = [aws_autoscaling_policy.web_scale_in.arn]
}
resource "aws_cloudwatch_metric_alarm" "app_mem_high" {
  alarm_name           = "app-mem-high"
  metric_name          = "mem_used_percent"
  namespace            = "CWAgent"
  comparison_operator  = "GreaterThanThreshold"
  threshold            = 80
  evaluation_periods   = 2
  period               = 60
  statistic            = "Average"
  dimensions           = { AutoScalingGroupName = aws_autoscaling_group.app.name }
  alarm_actions        = [aws_autoscaling_policy.app_scale_out.arn]
}
resource "aws_cloudwatch_metric_alarm" "app_mem_low" {
  alarm_name           = "app-mem-low"
  metric_name          = "mem_used_percent"
  namespace            = "CWAgent"
  comparison_operator  = "LessThanThreshold"
  threshold            = 30
  evaluation_periods   = 2
  period               = 60
  statistic            = "Average"
  dimensions           = { AutoScalingGroupName = aws_autoscaling_group.app.name }
  alarm_actions        = [aws_autoscaling_policy.app_scale_in.arn]
}
