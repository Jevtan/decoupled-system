output "registration_queue_url" {
  value = aws_sqs_queue.registration_queue.url
}

output "attendance_queue_url" {
  value = aws_sqs_queue.attendance_queue.url
}

output "certificate_queue_url" {
  value = aws_sqs_queue.certificate_queue.url
}

output "queue_arns" {
  value = [
    aws_sqs_queue.registration_queue.arn,
    aws_sqs_queue.attendance_queue.arn,
    aws_sqs_queue.certificate_queue.arn
  ]
}
