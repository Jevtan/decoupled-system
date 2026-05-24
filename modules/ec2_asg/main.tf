resource "aws_launch_template" "this" {
  name_prefix   = var.launch_template_name
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name = "webinar-keypair"
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile {
  name = "LabInstanceProfile"
}

user_data = base64encode(<<-EOF
  #!/bin/bash
  yum update -y
  yum install -y nodejs git
  cd /home/ec2-user
  git clone https://github.com/USERNAME/REPO_KAMU.git app
  cd app
  npm install
  npm start &
EOF
)
}

resource "aws_autoscaling_group" "this" {
  name                      = var.asg_name
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.subnet_ids
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  target_group_arns         = var.target_group_arns
  health_check_type         = "EC2"
  health_check_grace_period = 300
}

resource "aws_cloudwatch_metric_alarm" "queue_scale_out" {
  count               = var.enable_queue_scaling ? 1 : 0
  alarm_name          = "${var.asg_name}-queue-scale-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Average"
  threshold           = var.queue_length_scale_out
  dimensions = {
    QueueName = var.scaling_queue_name
  }
  alarm_actions = [aws_autoscaling_policy.scale_out_queue[0].arn]
}


resource "aws_cloudwatch_metric_alarm" "queue_scale_in" {
  count               = var.enable_queue_scaling ? 1 : 0
  alarm_name          = "${var.asg_name}-queue-scale-in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Average"
  threshold           = var.queue_length_scale_in
  dimensions = {
    QueueName = var.scaling_queue_name
  }
  alarm_actions = [aws_autoscaling_policy.scale_in_queue[0].arn]
}


resource "aws_autoscaling_policy" "scale_out_queue" {
  count                  = var.enable_queue_scaling ? 1 : 0
  name                   = "${var.asg_name}-scale-out-queue"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.queue_scale_out_cooldown
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "SimpleScaling"
}


resource "aws_autoscaling_policy" "scale_in_queue" {
  count                  = var.enable_queue_scaling ? 1 : 0
  name                   = "${var.asg_name}-scale-in-queue"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.queue_scale_in_cooldown
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "SimpleScaling"
}


# CPU-based scaling
resource "aws_cloudwatch_metric_alarm" "cpu_scale_out" {
  count               = var.enable_cpu_scaling ? 1 : 0
  alarm_name          = "${var.asg_name}-cpu-scale-out"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_out_threshold
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_out_cpu[0].arn]
}


resource "aws_cloudwatch_metric_alarm" "cpu_scale_in" {
  count               = var.enable_cpu_scaling ? 1 : 0
  alarm_name          = "${var.asg_name}-cpu-scale-in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_in_threshold
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_in_cpu[0].arn]
}


resource "aws_autoscaling_policy" "scale_out_cpu" {
  count                  = var.enable_cpu_scaling ? 1 : 0
  name                   = "${var.asg_name}-scale-out-cpu"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.cpu_scale_out_cooldown
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "SimpleScaling"
}


resource "aws_autoscaling_policy" "scale_in_cpu" {
  count                  = var.enable_cpu_scaling ? 1 : 0
  name                   = "${var.asg_name}-scale-in-cpu"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.cpu_scale_in_cooldown
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "SimpleScaling"
}

