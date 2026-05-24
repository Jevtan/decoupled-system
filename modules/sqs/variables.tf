variable "registration_queue_name" {
  type    = string
  default = "registration-queue"
}

variable "attendance_queue_name" {
  type    = string
  default = "attendance-queue"
}

variable "certificate_queue_name" {
  type    = string
  default = "certificate-queue"
}

variable "visibility_timeout_seconds" {
  type    = number
  default = 30
}
