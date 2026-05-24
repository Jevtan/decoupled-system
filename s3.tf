module "s3" {
  source                  = "./modules/s3"
  website_bucket_name     = "webinar-static-jevin-2026"
  certificate_bucket_name = "webinar-certificate-jevin-2026"
}