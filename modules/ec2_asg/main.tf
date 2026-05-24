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
set -x
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

# Update system
apt-get update -y
apt-get install -y nodejs npm

# Buat app folder
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app

# Buat server.js
cat > server.js << 'SERVEREOF'
const http = require('http');
const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');

const sqs = new SQSClient({ region: 'us-east-1' });
const QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/788507585127/attendance-queue';

const server = http.createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  
  if (req.method === 'POST' && req.url === '/register') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        await sqs.send(new SendMessageCommand({
          QueueUrl: QUEUE_URL,
          MessageBody: body || JSON.stringify({ timestamp: Date.now() })
        }));
        res.writeHead(202);
        res.end(JSON.stringify({ status: 'queued' }));
      } catch (e) {
        res.writeHead(500);
        res.end(JSON.stringify({ error: e.message }));
      }
    });
  } else if (req.url === '/health') {
    res.writeHead(200);
    res.end('OK');
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});

server.listen(80, '0.0.0.0', () => console.log('Server running on port 80'));
SERVEREOF

# Install npm deps
npm init -y
npm install @aws-sdk/client-sqs

# Run server with sudo (port 80 butuh root)
sudo -u root node server.js > /var/log/app.log 2>&1 &
EOF
)

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

