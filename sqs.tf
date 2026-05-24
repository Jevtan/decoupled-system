module "sqs" {
  source = "./modules/sqs"
  # Variabel bisa diubah sesuai kebutuhan
  registration_queue_name    = "registration-queue"
  attendance_queue_name      = "attendance-queue"
  certificate_queue_name     = "certificate-queue"
  visibility_timeout_seconds = 30
}