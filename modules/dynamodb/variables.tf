variable "table_name" {
  type    = string
  default = "attendance-tracking"
}

variable "hash_key" {
  type    = string
  default = "attendance_id"
}

variable "hash_key_type" {
  type    = string
  default = "S"
}
