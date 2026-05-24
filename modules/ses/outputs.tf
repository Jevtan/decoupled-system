output "ses_identity_arn" {
  value = aws_ses_email_identity.this.arn
}

output "ses_identity_email" {
  value = aws_ses_email_identity.this.email
}
