terraform {
  required_version = "1.4.5"
  backend "s3" {
    bucket         = "terraform-state-storage-863362256468" # TODO: change to true account
    dynamodb_table = "terraform-state-lock-863362256468"
    key            = "web-cdn/dev/setup.tfstate"
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

locals {
  env = "dev"
}

variable "cdn_name" {
  type = string
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      repo                   = "https://github.com/byu-oit/web-cdn"
      data-sensitivity       = "public"
      env                    = local.env
      resource-creator-email = "GitHub-Actions"
    }
  }
}

module "setup" {
  source = "../../modules/setup/"
  env    = local.env
  cdn_name = var.cdn_name
}
