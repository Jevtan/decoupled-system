resource "aws_launch_template" "this" {
  name_prefix   = var.launch_template_name
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = "webinar-keypair"
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile {
    name = "LabInstanceProfile"
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
set -x
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

# Install Node.js
apt-get update -y
apt-get install -y nodejs npm

# Buat app folder
mkdir -p /app
cd /app

# Create server.js
cat > server.js << 'SERVEREOF'
const http = require('http');
const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  if (req.url === '/health') {
    res.writeHead(200);
    res.end('OK');
  } else if (req.method === 'POST' && req.url === '/register') {
    res.writeHead(202);
    res.end(JSON.stringify({ status: 'queued' }));
  } else {
    res.writeHead(404);
    res.end('Not found');
  }
});
server.listen(80, '0.0.0.0', () => console.log('Server running on port 80'));
SERVEREOF

# Run server as root (port 80 needs root)
nohup node server.js > /var/log/app.log 2>&1 &

EOF
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