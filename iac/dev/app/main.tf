terraform {
  required_version = "1.4.5"
  backend "s3" {
    bucket         = "terraform-state-storage-863362256468" # TODO: change to true account
    dynamodb_table = "terraform-state-lock-863362256468"
    key            = "web-cdn/dev/app.tfstate"
    region         = "us-west-2"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.63"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

variable "image_tag" {
  type = string
}

locals {
  env = "dev"
}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      repo                   = "https://github.com/byu-oit/web-cdn"
      data-sensitivity       = "public"
      env                    = local.env
      resource-creator-email = "GitHub-Actions"
    }
  }
}

variable "cdn_name" {
  type = string
}

module "app" {
  source = "../../modules/app/"
  env    = local.env
  cdn_name = var.cdn_name
  image_tag = var.image_tag
  s3_bucket_name = "${var.cdn_name}-${local.env}-contents"
  index_document_name = "index.html"
  error_document_name = "error.html"
  force_destroy = true
}
