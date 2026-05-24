output "website_bucket_arn" {
  value = aws_s3_bucket.website.arn
}

output "certificate_bucket_arn" {
  value = aws_s3_bucket.certificate.arn
}

output "website_bucket_domain_name" {
  value = aws_s3_bucket.website.bucket_domain_name
}
