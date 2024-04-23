variable "name" {
  type = string
}

variable "env" {
  type = string
}

variable "config_branch" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "force_destroy" {
  type = bool
}

variable "stage_name" {
  type = string
}

variable "cdn_url" {
  type = string
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

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "cdn_zone" {
  name = var.cdn_url
}

data "aws_ecr_repository" "assembler_ecr_repo" {
  name = "${local.app_name}-assembler"
}

data "aws_ecr_repository" "webhooks_repo" {
  name = "${local.app_name}-webhooks"
}

data "aws_ecr_repository" "log_sorter_ecr_repo" {
  name = "${local.app_name}-log-sorter"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.5.0"
}

locals {
  unprocessed_log_prefix  = "cloudfront/unprocessed"
  preprocessed_log_prefix = "cloudfront/preprocessed"
  app_name                = "${var.name}-${var.env}"
}
