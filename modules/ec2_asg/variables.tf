variable "launch_template_name" {
  type    = string
  default = "webinar-launch-template"
}

variable "asg_name" {
  type    = string
  default = "webinar-asg"
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type = string
}

variable "user_data" {
  type    = string
  default = ""
}

variable "security_group_ids" {
  type = list(string)
}

variable "subnet_ids" {
  type = list(string)
}

variable "target_group_arns" {
  type = list(string)
  default = []
}

variable "max_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "enable_queue_scaling" {
  type    = bool
  default = false
}

variable "scaling_queue_name" {
  type    = string
  default = ""
}

variable "queue_length_scale_out" {
  type    = number
  default = 50
}

variable "queue_length_scale_in" {
  type    = number
  default = 10
}

variable "queue_scale_out_cooldown" {
  type    = number
  default = 60
}

variable "queue_scale_in_cooldown" {
  type    = number
  default = 300
}

variable "enable_cpu_scaling" {
  type    = bool
  default = false
}

variable "cpu_scale_out_threshold" {
  type    = number
  default = 70
}

variable "cpu_scale_in_threshold" {
  type    = number
  default = 30
}

variable "cpu_scale_out_cooldown" {
  type    = number
  default = 300
}

variable "cpu_scale_in_cooldown" {
  type    = number
  default = 600
}

variable "instance_profile_name" {
  type = string
  default = "LabInstanceProfile"
}
