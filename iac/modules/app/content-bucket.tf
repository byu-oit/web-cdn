
variable "s3_bucket_name" {
  description = "Name of S3 bucket for website"
}

# TODO possibly add allow CORS
resource "aws_s3_bucket" "CdnContentBucket" {
  bucket = "${var.cdn_name}-${var.env}-contents-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "content_bucket" {
  bucket = aws_s3_bucket.CdnContentBucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "content_bucket" {
  bucket = aws_s3_bucket.CdnContentBucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}


resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.CdnContentBucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.CdnContentBucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "content_bucket_config" {
  bucket = aws_s3_bucket.CdnContentBucket.id

  rule {
    id = "ExpireOldVersions"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }

  rule {
    id = "RemoveOldBlobs"
    status = "Enabled"
    filter {
      prefix = ".cdn-infra/file-blobs/"
    }
    expiration {
      days = 60
    }
  }
}

resource "aws_s3_bucket_website_configuration" "CdnContentBucket" {
  bucket = aws_s3_bucket.CdnContentBucket.id
  index_document {
    suffix = var.index_document_name
  }
  error_document {
    key = var.error_document_name
  }
}

resource "aws_s3_bucket_acl" "content_bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.content_bucket,
    aws_s3_bucket_public_access_block.content_bucket,
  ]

  bucket = aws_s3_bucket.CdnContentBucket.id
  acl    = "public-read"
}
