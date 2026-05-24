variable "alb_name" {
  type    = string
  default = "webinar-alb"
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "target_group_name" {
  type = string
}

variable "listener_port" {
  type = number
}

variable "listener_protocol" {
  type = string
}
