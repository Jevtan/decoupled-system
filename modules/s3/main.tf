resource "aws_s3_bucket" "website" {
  bucket = "webinar-static-jevin-2026"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

resource "aws_s3_bucket" "certificate" {
  bucket = "webinar-certificate-jevin-2026"
  acl    = "private"
}
