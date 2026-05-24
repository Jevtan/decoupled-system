variable "role_name" {
  type        = string
  description = "Prefix nama untuk IAM role dan profile"
  default     = "webinar-system"
}

variable "sqs_queue_arns" {
  type        = list(string)
  description = "List ARN semua SQS queue yang boleh diakses EC2"
  default     = []
}

