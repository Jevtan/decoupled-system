resource "aws_launch_template" "this" {
  name_prefix   = var.launch_template_name
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = "webinar-keypair"
  network_interfaces {
  associate_public_ip_address = true
  security_groups             = var.security_group_ids
  }
  iam_instance_profile {
    name = "LabInstanceProfile"
  }

user_data = base64encode(<<-USERDATA
#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

mkdir -p /app
cd /app
npm init -y
npm install @aws-sdk/client-sqs

cat > /app/server.js << 'EOF'
const http = require('http');
const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');

const sqs = new SQSClient({ region: 'us-east-1' });
const QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/028620776823/attendance-queue';

const server = http.createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');

  if (req.url === '/health') {
    res.writeHead(200);
    res.end('OK');

  } else if (req.method === 'POST' && req.url === '/register') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', async () => {
      try {
        await sqs.send(new SendMessageCommand({
          QueueUrl: QUEUE_URL,
          MessageBody: body || JSON.stringify({ timestamp: Date.now() }),
        }));
        res.writeHead(202);
        res.end(JSON.stringify({ status: 'queued' }));
      } catch (err) {
        console.error('SQS error:', err.message);
        res.writeHead(500);
        res.end(JSON.stringify({ error: err.message }));
      }
    });

  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});

server.listen(80, '0.0.0.0', () => console.log('Server running on port 80'));
EOF

cat > /etc/systemd/system/webinar-app.service << 'EOF'
[Unit]
Description=Webinar App
After=network.target

[Service]
ExecStart=/usr/bin/node /app/server.js
Restart=always
RestartSec=3
User=root
WorkingDirectory=/app

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable webinar-app
systemctl start webinar-app

USERDATA
)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "webinar-instance"
    }
  }
}

resource "aws_autoscaling_group" "this" {
  name                = var.asg_name
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  tag {
    key                 = "Name"
    value               = "webinar-asg-instance"
    propagate_at_launch = true
  }
}

# ── Queue-based scaling alarms ──────────────────────────────
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
  dimensions          = { QueueName = var.scaling_queue_name }
  alarm_actions       = [aws_autoscaling_policy.scale_out_queue[0].arn]
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
  dimensions          = { QueueName = var.scaling_queue_name }
  alarm_actions       = [aws_autoscaling_policy.scale_in_queue[0].arn]
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

# ── CPU-based scaling alarms ─────────────────────────────────
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
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.this.name }
  alarm_actions       = [aws_autoscaling_policy.scale_out_cpu[0].arn]
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
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.this.name }
  alarm_actions       = [aws_autoscaling_policy.scale_in_cpu[0].arn]
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