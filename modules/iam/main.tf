resource "aws_iam_role" "ec2_role" {
  name = "${var.role_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Policy: Baca SQS (receive, delete, get attributes)
resource "aws_iam_role_policy" "sqs_policy" {
  name = "${var.role_name}-sqs-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:SendMessage",
        "sqs:GetQueueUrl"
      ]
      Resource = var.sqs_queue_arns
    }]
  })
}

# Policy: Tulis custom metrics dan baca CloudWatch
resource "aws_iam_role_policy" "cloudwatch_policy" {
  name = "${var.role_name}-cloudwatch-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:PutMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    }]
  })
}

# Instance Profile (yang dipasang ke EC2/Launch Template)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.role_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}