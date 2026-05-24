output "instance_profile_name" {
  value       = aws_iam_instance_profile.ec2_profile.name
  description = "Nama Instance Profile yang dipasang ke Launch Template EC2"
}

output "instance_profile_arn" {
  value       = aws_iam_instance_profile.ec2_profile.arn
  description = "ARN Instance Profile"
}

output "role_arn" {
  value       = aws_iam_role.ec2_role.arn
  description = "ARN IAM Role"
}
