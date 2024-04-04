variable "cdn_name" {
  type = string
}

variable "env" {
  type = string
}

variable "image_tag" {
  type = string
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
