variable "cdn_name" {
  type = string
}

variable "env" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "force_destroy" {
  type = bool
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  root_dns_name           = module.acs.route53_zone.name # TODO change to real dns when cutover
  root_dns_id             = module.acs.route53_zone.id   # TODO change to real dns when cutover
  unprocessed_log_prefix  = "cloudfront/unprocessed"
  preprocessed_log_prefix = "cloudfront/preprocessed"
}
