variable "s3_bucket_name" {
  description = "Name of S3 bucket for website"
}

variable "force_destroy" {
  default = false
}

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

resource "aws_s3_bucket" "website" {
  bucket        = var.s3_bucket_name
  tags          = { "divvy-ignore-s3-public" = "true" }
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = var.index_document_name
  }
  error_document {
    key = var.error_document_name
  }
}

resource "aws_acm_certificate" "cert" {
  provider                  = aws.aws_n_va
  domain_name               = var.site_url
  #  subject_alternative_names = [for domain in var.additional_domains : domain.domain]
  validation_method         = "DNS"
  #  tags                      = var.tags
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.aws_n_va
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn] # FIXME: set up route53
}

resource "aws_cloudfront_distribution" "WebsiteCloudfront" {
  #  comment = "${var.RootDNS} - ${var.CDNName} ${var.Environment}"

  #  aliases = ["${var.}"]

  enabled = true
  http_version = "http2"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    compress         = true
    target_origin_id = "only-origin"
    viewer_protocol_policy = "redirect-to-https"
    #    default_ttl      = "${lookup(var.NormalCacheTTL[terraform.workspace], "default")}"
    #    max_ttl          = "${lookup(var.NormalCacheTTL[terraform.workspace], "max")}"
    #    min_ttl          = "${lookup(var.NormalCacheTTL[terraform.workspace], "min")}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    lambda_function_association {
      event_type       = "origin-request"
      lambda_arn       = aws_lambda_function.eager_redirect_func.arn
    }

    lambda_function_association {
      event_type       = "origin-response"
      lambda_arn       = aws_lambda_function.enhanced_headers_func.arn
    }
  }

  # TODO: wait for logging
  #  logging_config {
  #    bucket = "${aws_s3_bucket.LogBucket.bucket_domain_name}"
  #    prefix = "${lookup(var.LogPrefixes[terraform.workspace], "cloudfront")}"
  #  }

  default_root_object = "index.html" # TODO: abstract to variables?
  price_class         = "PriceClass_100"
  is_ipv6_enabled        = true

  origin {
    origin_id         = "only-origin"
    domain_name = aws_s3_bucket_website_configuration.website_config.website_endpoint

    #    s3_origin_config {
    #      origin_access_identity = ""
    #    }

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  tags = {
    Name = "${var.cdn_name} ${var.env} Distribution"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }
}
