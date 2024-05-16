## ==================== HTTPS cert ====================
#resource "aws_acm_certificate" "cert" {
#  domain_name               = var.cdn_url
#  validation_method         = "DNS"
#  subject_alternative_names = ["*.${var.cdn_url}"]
#}
#
#resource "aws_acm_certificate_validation" "cert" {
#  certificate_arn         = aws_acm_certificate.cert.arn
#  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
#}
#
#resource "aws_route53_record" "cert_validation" {
#  for_each = {
#    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
#      name   = dvo.resource_record_name
#      record = dvo.resource_record_value
#      type   = dvo.resource_record_type
#    }
#  }
#
#  allow_overwrite = true
#  name            = each.value.name
#  type            = each.value.type
#  zone_id         = data.aws_route53_zone.cdn_zone.id
#  records         = [each.value.record]
#  ttl             = 60
#}

# ==================== Route53 ====================
resource "aws_route53_record" "a_record" {
  name            = "${local.app_name}-${var.env}"
  type            = "A"
  zone_id         = data.aws_route53_zone.cdn_zone.id
  allow_overwrite = false
  alias {
    name                   = aws_cloudfront_distribution.website_cloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.website_cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa_record" {
  name            = "${local.app_name}-${var.env}"
  type            = "AAAA"
  zone_id         = data.aws_route53_zone.cdn_zone.id
  allow_overwrite = false
  alias {
    name                   = aws_cloudfront_distribution.website_cloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.website_cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}

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
        "Resource" : "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.name}/${var.env}*"
      }
    ]
  })
}

resource "aws_cloudfront_distribution" "website_cloudfront" {
  comment      = "${var.cdn_url} - ${var.name} ${var.env}"
  aliases      = ["${local.app_name}.${var.cdn_url}"]
  enabled      = true
  http_version = "http2"

  viewer_certificate {
    acm_certificate_arn      = module.acs.certificate_virginia.arn # aws_acm_certificate.new_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1"
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
