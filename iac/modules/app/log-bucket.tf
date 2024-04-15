
resource "aws_s3_bucket" "log_bucket" {
  bucket        = "${var.cdn_name}-${var.env}-logs-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "log_bucket" {
  depends_on = [aws_s3_bucket_public_access_block.log_bucket]
  bucket     = aws_s3_bucket.log_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket_config" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "ExpireUnprocessedLogs"
    status = "Enabled"
    expiration {
      days = 60
    }
    filter {
      prefix = local.unprocessed_log_prefix
    }
  }

  rule {
    id     = "UnprocessedLogsToInfrequentAccess"
    status = "Enabled"
    filter {
      prefix = local.unprocessed_log_prefix
    }
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "ExpirePreprocessedLogs"
    status = "Enabled"
    expiration {
      days = 10
    }
    filter {
      prefix = local.preprocessed_log_prefix
    }
  }
}

#resource "aws_s3_bucket_acl" "log_bucket" {
#  depends_on = [
#    aws_s3_bucket_ownership_controls.log_bucket,
#    aws_s3_bucket_public_access_block.log_bucket,
#  ]
#
#  bucket = aws_s3_bucket.LogBucket.id
#  acl    = "log"
#}

resource "aws_s3_bucket_server_side_encryption_configuration" "logging_encryption" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy to allow things with a certain role to add stuff to this bucket
resource "aws_s3_bucket_policy" "LogBucketAllowLogPutsUpdates" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : aws_iam_role.edge_lambda_execution_role.arn
        },
        "Action" : [
          "s3:ListBucket",
          "s3:PutBucketWebsite",
          "s3:Get*"
        ],
        "Resource" = aws_s3_bucket.log_bucket.arn
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : aws_iam_role.edge_lambda_execution_role.arn
        },
        "Action" : [
          "s3:*"
        ],
        "Resource" = "${aws_s3_bucket.log_bucket.arn}/*"
      }
    ]
  })
}
