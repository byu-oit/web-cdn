terraform {
  required_version = "1.4.5"
  backend "s3" {
    bucket         = "terraform-state-storage-637423550675"
    dynamodb_table = "terraform-state-lock-637423550675"
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
  env           = "dev"
  name          = "web-cdn"
  config_branch = "terraform" //TODO: change me to dev when we cutover
  stage_name    = "dev"
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

module "app" {
  source              = "../../modules/app/"
  env                 = local.env
  name                = local.name
  image_tag           = var.image_tag
  index_document_name = "index.html"
  error_document_name = "error.html"
  default_ttl         = 30
  max_ttl             = 60
  min_ttl             = 0
  force_destroy       = true
  config_branch       = local.config_branch
  stage_name          = local.stage_name
  cdn_url             = "cdn-dev.byu.edu"
}
