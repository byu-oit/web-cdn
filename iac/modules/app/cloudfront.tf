
variable "index_document_name" {
  type        = string
  default     = "index.html"
  description = "The index document of the site."
}

variable "error_document_name" {
  type        = string
  default     = "index.html"
  description = "The error document (e.g. 404 page) of the site."
}

variable "site_url" {
  type        = string
  description = "The URL for the site."
}

variable "default_ttl" {
  type        = string
  description = "Cloudfront cache default ttl"
}

variable "max_ttl" {
  type        = string
  description = "Cloudfront cache max ttl"
}

variable "min_ttl" {
  type        = string
  description = "Cloudfront cache min ttl"
}

# ==================== HTTPS cert ====================
#resource "aws_acm_certificate" "new_cert" {
#  domain_name               = "${var.cdn_name}.${local.root_dns_name}" # TODO change when we use the real domain instead of the account domain
#  validation_method         = "DNS"
#  subject_alternative_names = ["*.${var.cdn_name}.${local.root_dns_name}"]
#}
#resource "aws_acm_certificate_validation" "new_cert" {
#  certificate_arn         = aws_acm_certificate.new_cert.arn
#  validation_record_fqdns = [for record in aws_route53_record.new_cert_validation : record.fqdn]
#}

# ==================== Route53 ====================
resource "aws_route53_record" "a_record" {
  name            = "${var.cdn_name}-${var.env}"
  type            = "A"
  zone_id         = local.root_dns_id
  allow_overwrite = false
  alias {
    name                   = aws_cloudfront_distribution.website_cloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.website_cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa_record" {
  name            = "${var.cdn_name}-${var.env}"
  type            = "AAAA"
  zone_id         = local.root_dns_id
  allow_overwrite = false
  alias {
    name                   = aws_cloudfront_distribution.website_cloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.website_cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}

#resource "aws_route53_record" "new_cert_validation" {
#  for_each = {
#    for dvo in aws_acm_certificate.new_cert.domain_validation_options : dvo.domain_name => {
#      name   = dvo.resource_record_name
#      record = dvo.resource_record_value
#      type   = dvo.resource_record_type
#    }
#  }
#
#  allow_overwrite = true
#  name            = each.value.name
#  type            = each.value.type
#  zone_id         = local.root_dns_id
#  records         = [each.value.record]
#  ttl             = 60
#}
#
# data "aws_route53_record" "existing_record" {
#   zone_id = local.root_dns_id
#   name    = "_3c077e2b2d1354f739d9880494eaec9b.byu-oit-fullstack-trn.amazon.byu.edu"
#   type    = "CNAME"
# }

resource "aws_iam_policy" "allow_cdn_parameter_store_access" {
  name        = "AllowCdnParameterStoreAccess"
  description = "Allows access to CDN parameter store"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:DescribeParameters",
          "ssm:GetParameters"
        ],
        "Resource" : "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.cdn_name}/*"
      }
    ]
  })
}

resource "aws_iam_policy" "allow_cloudfront_invalidation" {
  name        = "AllowCloudFrontInvalidation"
  description = "Allows CloudFront invalidation"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_cloudfront_distribution" "website_cloudfront" {
  comment      = "${local.root_dns_name} - ${var.cdn_name} ${var.env}"
  aliases      = ["${var.cdn_name}-${var.env}.${local.root_dns_name}"]
  enabled      = true
  http_version = "http2"

  viewer_certificate {
    acm_certificate_arn      = module.acs.certificate_virginia.arn # aws_acm_certificate.new_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1" # TLSv1.2_2019
  }

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    compress        = true
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    target_origin_id       = "only-origin"
    viewer_protocol_policy = "redirect-to-https"
    default_ttl            = var.default_ttl
    max_ttl                = var.max_ttl
    min_ttl                = var.min_ttl

    lambda_function_association {
      event_type = "origin-request"
      lambda_arn = aws_lambda_function.eager_redirect_func.qualified_arn
    }

    lambda_function_association {
      event_type = "origin-response"
      lambda_arn = aws_lambda_function.enhanced_headers_func.qualified_arn
    }
  }

  ordered_cache_behavior {
    path_pattern    = "/.cdn-infra/*"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    compress        = true
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    target_origin_id       = "only-origin"
    viewer_protocol_policy = "redirect-to-https"
    default_ttl            = var.default_ttl
    max_ttl                = var.max_ttl
    min_ttl                = var.min_ttl

    lambda_function_association {
      event_type   = "origin-response"
      lambda_arn   = aws_lambda_function.enhanced_headers_func.qualified_arn
      include_body = false
    }
  }

  logging_config {
    bucket = aws_s3_bucket.log_bucket.bucket_domain_name
    prefix = local.unprocessed_log_prefix
  }

  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  is_ipv6_enabled     = true

  origin {
    origin_id   = "only-origin"
    domain_name = aws_s3_bucket.cdn_content_bucket.bucket_domain_name
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
