output "registration_queue_url" {
  value = module.sqs.registration_queue_url
}

output "attendance_queue_url" {
  value = module.sqs.attendance_queue_url
}

output "certificate_queue_url" {
  value = module.sqs.certificate_queue_url
}

output "website_bucket_arn" {
  value = module.s3.website_bucket_arn
}

output "certificate_bucket_arn" {
  value = module.s3.certificate_bucket_arn
}

output "website_bucket_domain_name" {
  value = module.s3.website_bucket_domain_name
}
