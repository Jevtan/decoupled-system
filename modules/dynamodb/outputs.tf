output "attendance_table_arn" {
  value = aws_dynamodb_table.attendance.arn
}

output "attendance_table_name" {
  value = aws_dynamodb_table.attendance.name
}
