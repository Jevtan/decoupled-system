resource "aws_s3_bucket" "website" {
  bucket = "webinar-static-jevin-20260601a"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

resource "aws_s3_bucket" "certificate" {
  bucket = "webinar-certificate-jevin-20260601a"
  acl    = "private"
}
