#resource "aws_cloudfront_distribution" "WebsiteCloudfront" {
##  comment = "${var.RootDNS} - ${var.CDNName} ${var.Environment}"
#
##  aliases = ["${var.}"]
#
#  enabled = true
#  http_version = "http2"
#
#  default_cache_behavior {
#    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
#    compress         = true
#    target_origin_id = "only-origin"
#    viewer_protocol_policy = "redirect-to-https"
#    cached_methods = ["GET"]
##    default_ttl      = "${lookup(var.NormalCacheTTL[terraform.workspace], "default")}"
##    max_ttl          = "${lookup(var.NormalCacheTTL[terraform.workspace], "max")}"
##    min_ttl          = "${lookup(var.NormalCacheTTL[terraform.workspace], "min")}"
#
#    forwarded_values {
#      query_string = false
#      cookies {
#        forward = "none"
#      }
#    }
#
#    lambda_function_association {
#      event_type       = "origin-request"
#      lambda_arn       = aws_lambda_function.eager_redirect_func.arn
#    }
#
#    lambda_function_association {
#      event_type       = "origin-response"
#      lambda_arn       = aws_lambda_function.enhanced_headers_func.arn
#    }
#  }
#
##  logging_config {
##    bucket = "${aws_s3_bucket.LogBucket.bucket_domain_name}"
##    prefix = "${lookup(var.LogPrefixes[terraform.workspace], "cloudfront")}"
##  }
#
#  default_root_object = "index.html"
#  price_class         = "PriceClass_100"
#  is_ipv6_enabled        = true
#
#  origin {
#    origin_id         = "only-origin"
#    domain_name = ""
#
#    s3_origin_config {
#      origin_access_identity = ""
#    }
#  }
#
#  tags = {
#    Name = "${var.cdn_name} ${var.env} Distribution"
#  }
#
#  restrictions {
#    geo_restriction {
#      restriction_type = "none"
#    }
#  }
#
#  viewer_certificate {
##    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
#    ssl_support_method       = "sni-only"
#    minimum_protocol_version = "TLSv1.2_2019"
#  }
#}
