module "alb" {
  source             = "./modules/alb"
  alb_name           = "webinar-alb"
  vpc_id             = "vpc-0e9d5af7cf72d6a3b"
  subnet_ids         = ["subnet-0117c22d29b28d4b0", "subnet-0763a20e2d41f384f"]  # 1a dan 1b — 2 AZ berbeda
  security_group_ids = ["sg-0198205ac894f48ec"]
  target_group_name  = "webinar-target-group"
  listener_port      = 80
  listener_protocol  = "HTTP"
}

module "asg_queue" {
  source                   = "./modules/ec2_asg"
  asg_name                 = "asg-queue-based"
  enable_queue_scaling     = true
  enable_cpu_scaling       = false
  queue_length_scale_out   = 50
  queue_length_scale_in    = 10
  queue_scale_out_cooldown = 60
  queue_scale_in_cooldown  = 300
  scaling_queue_name       = "attendance-queue"
  min_size                 = 1
  max_size                 = 10
  ami_id                   = "ami-0b6c6ebed2801a5cb"
  instance_type            = "t3.medium"
  key_name                 = "my-keypair"
  security_group_ids       = ["sg-0198205ac894f48ec"]
  subnet_ids               = ["subnet-0117c22d29b28d4b0"]  # us-east-1a
  target_group_arns        = [module.alb.target_group_arn]
  instance_profile_name    = "LabInstanceProfile"
}

module "asg_cpu" {
  source                  = "./modules/ec2_asg"
  asg_name                = "asg-cpu-based"
  enable_queue_scaling    = false
  enable_cpu_scaling      = true
  cpu_scale_out_threshold = 70
  cpu_scale_in_threshold  = 30
  cpu_scale_out_cooldown  = 300
  cpu_scale_in_cooldown   = 600
  min_size                = 1
  max_size                = 10
  ami_id                  = "ami-0b6c6ebed2801a5cb"
  instance_type           = "t3.medium"
  key_name                = "my-keypair"
  security_group_ids      = ["sg-0198205ac894f48ec"]
  subnet_ids              = ["subnet-0117c22d29b28d4b0"]  # us-east-1a
  target_group_arns       = [module.alb.target_group_arn]
  instance_profile_name   = "LabInstanceProfile"
}

# module "iam" {
#   source         = "./modules/iam"
#   role_name      = "webinar-system"
#   sqs_queue_arns = module.sqs.queue_arns
# }