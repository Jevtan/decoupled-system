resource "aws_sqs_queue" "registration_queue" {
  name                      = var.registration_queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
}

resource "aws_sqs_queue" "attendance_queue" {
  name                      = var.attendance_queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
}

resource "aws_sqs_queue" "certificate_queue" {
  name                      = var.certificate_queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
}

# =========================================================
# TAMBAHAN 1: Dead Letter Queue (DLQ) untuk setiap queue
# Tambahkan ke modules/sqs/main.tf yang sudah ada
# =========================================================

# DLQ untuk registration
resource "aws_sqs_queue" "registration_dlq" {
  name                      = "${var.registration_queue_name}-dlq"
  message_retention_seconds = 1209600 # 14 hari — simpan untuk analisis
}

# DLQ untuk attendance
resource "aws_sqs_queue" "attendance_dlq" {
  name                      = "${var.attendance_queue_name}-dlq"
  message_retention_seconds = 1209600
}

# DLQ untuk certificate
resource "aws_sqs_queue" "certificate_dlq" {
  name                      = "${var.certificate_queue_name}-dlq"
  message_retention_seconds = 1209600
}

# Hubungkan DLQ ke queue utama dengan redrive policy
resource "aws_sqs_queue_redrive_policy" "registration" {
  queue_url = aws_sqs_queue.registration_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.registration_dlq.arn
    maxReceiveCount     = 3  # Setelah 3x gagal diproses, masuk DLQ
  })
}

resource "aws_sqs_queue_redrive_policy" "attendance" {
  queue_url = aws_sqs_queue.attendance_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.attendance_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_redrive_policy" "certificate" {
  queue_url = aws_sqs_queue.certificate_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.certificate_dlq.arn
    maxReceiveCount     = 3
  })
}
