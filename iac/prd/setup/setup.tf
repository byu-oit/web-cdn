terraform {
  required_version = "1.4.5"
  backend "s3" {
    bucket         = "terraform-state-storage-204581410681"
    dynamodb_table = "terraform-state-lock-204581410681"
    key            = "web-cdn/prd/setup.tfstate"
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
  env = "prd"
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

module "setup" {
  source      = "../../modules/setup/"
  env         = local.env
}
