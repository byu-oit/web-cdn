#data "" {
#  d
#}

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
#  domain_name               = "${var.cdn_name}.${local.root_dns_name}" # TODO double-check domain name
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
    name                   = aws_cloudfront_distribution.WebsiteCloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.WebsiteCloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa_record" {
  name            = "${var.cdn_name}-${var.env}"
  type            = "AAAA"
  zone_id         = local.root_dns_id
  allow_overwrite = false
  alias {
    name                   = aws_cloudfront_distribution.WebsiteCloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.WebsiteCloudfront.hosted_zone_id
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

resource "aws_cloudfront_distribution" "WebsiteCloudfront" {
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
    bucket = aws_s3_bucket.LogBucket.bucket_domain_name
    prefix = local.unprocessed_log_prefix
  }

  default_root_object = "index.html" # TODO: abstract to variables?
  price_class         = "PriceClass_100"
  is_ipv6_enabled     = true

  origin {
    origin_id   = "only-origin"
    domain_name = aws_s3_bucket.CdnContentBucket.bucket_domain_name

#    s3_origin_config {
#      origin_access_identity = ""
#    }

    # TODO: why is this commented in the cloudbuild spec???
    #    domain_name = aws_s3_bucket_website_configuration.CdnContentBucket.website_endpoint
    #    custom_origin_config {
    #      http_port              = "80"
    #      https_port             = "443"
    #      origin_protocol_policy = "http-only"
    #      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    #    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
