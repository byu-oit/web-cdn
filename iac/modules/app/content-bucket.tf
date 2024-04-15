
variable "s3_bucket_name" {
  description = "Name of S3 bucket for website"
}

resource "aws_s3_bucket" "cdn_content_bucket" {
  bucket = "${var.cdn_name}-${var.env}-contents-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_website_configuration" "cdn_content_bucket" {
  bucket = aws_s3_bucket.cdn_content_bucket.id
  index_document {
    suffix = var.index_document_name
  }
  error_document {
    key = var.error_document_name
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "content_bucket_config" {
  bucket = aws_s3_bucket.cdn_content_bucket.id

  rule {
    id     = "ExpireOldVersions"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }

  rule {
    id     = "RemoveOldBlobs"
    status = "Enabled"
    filter {
      prefix = ".cdn-infra/file-blobs/"
    }
    expiration {
      days = 60
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "content_encryption" {
  bucket = aws_s3_bucket.cdn_content_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "cors_config" {
  bucket = aws_s3_bucket.cdn_content_bucket.id
  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    max_age_seconds = 86400
  }
}

resource "random_string" "cf_key" {
  length  = 32
  special = false
}

#data "aws_iam_policy_document" "static_website" {
#  statement {
#    sid       = "1"
#    actions   = ["s3:ListBucket", "s3:PutBucketWebsite", "s3:Get*"]
#    resources = [aws_s3_bucket.CdnContentBucket.arn]
#
#    principals {
#      identifiers = ["*"]
#      type        = "AWS"
#    }
#
#    condition {
#      test     = "StringLike"
#      values   = [random_string.cf_key.result]
#      variable = "aws:Referer"
#    }
#  }
#  statement {
#    sid       = "2"
#    actions   = ["s3:*"]
#    resources = ["${aws_s3_bucket.CdnContentBucket.arn}/*"]
#
#    principals {
#      identifiers = ["*"]
#      type        = "AWS"
#    }
#  }
#}

resource "aws_s3_bucket_public_access_block" "content_bucket" {
  bucket = aws_s3_bucket.cdn_content_bucket.id

  block_public_acls       = false # SS is true
  block_public_policy     = false
  ignore_public_acls      = false # SS is true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "content_bucket" {
  depends_on = [aws_s3_bucket_public_access_block.content_bucket]
  bucket     = aws_s3_bucket.cdn_content_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

#resource "aws_s3_bucket_policy" "cdn_bucket_read" {
#  depends_on = [aws_s3_bucket_ownership_controls.content_bucket]
#  bucket     = aws_s3_bucket.CdnContentBucket.id
#  policy     = data.aws_iam_policy_document.static_website.json
#}

resource "aws_s3_bucket_acl" "content_bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.content_bucket,
    #    aws_s3_bucket_public_access_block.content_bucket,
  ]

  bucket = aws_s3_bucket.cdn_content_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.cdn_content_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
