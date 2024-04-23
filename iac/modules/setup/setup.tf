variable "env" {
  type = string
}

locals {
  gh_org  = "byu-oit"
  gh_repo = "web-cdn"
}

variable "name" {
  type = string
}

variable "cdn_url" {
  type = string
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v4.0.0"
}

module "gha_role" {
  source                         = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                        = "5.17.0"
  create_role                    = true
  role_name                      = "${var.name}-${var.env}-gha"
  provider_url                   = "token.actions.githubusercontent.com/brigham-young-university" # TODO: Fix this hardcode
  role_permissions_boundary_arn  = module.acs.role_permissions_boundary.arn
  role_policy_arns               = module.acs.power_builder_policies[*].arn
  oidc_fully_qualified_audiences = ["sts.amazonaws.com"]
  oidc_subjects_with_wildcards   = ["repo:${local.gh_org}/${local.gh_repo}:*"]
}

module "my_ecr" {
  for_each = toset(["assembler", "log-sorter", "webhooks"])
  source   = "github.com/byu-oit/terraform-aws-ecr?ref=v2.0.1"
  name     = "${var.name}-${var.env}-${each.key}"
}

# ==================== SSM Parameters ====================
resource "aws_ssm_parameter" "secrets" {
  for_each = {
    "GITHUB_TOKEN" = "temporary"
    "GITHUB_USER"  = "temporary"
  }
  name  = "/${var.name}/${var.env}/${each.key}"
  type  = "SecureString"
  value = each.value
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

resource "aws_route53_zone" "cdn_zone" {
  name = var.cdn_url
}
