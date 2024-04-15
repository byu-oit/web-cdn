module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.5.0"
}

data "aws_ecr_repository" "assembler_ecr_repo" {
  name = "${var.cdn_name}-assembler-${var.env}"
}

data "aws_ecr_repository" "webhooks_repo" {
  name = "${var.cdn_name}-webhooks-${var.env}"
}

data "aws_ecr_repository" "eager_redirect_ecr_repo" {
  name = "${var.cdn_name}-eager-redirect-${var.env}"
}

data "aws_ecr_repository" "enhanced_headers_ecr_repo" {
  name = "${var.cdn_name}-enhanced-headers-${var.env}"
}

data "aws_ecr_repository" "log_sorter_ecr_repo" {
  name = "${var.cdn_name}-log-sorter-${var.env}"
}

# EdgeLambdaExecutionRole
resource "aws_iam_role" "edge_lambda_execution_role" {
  name                 = "EdgeLambdaExecutionRole"
  path                 = "/${var.cdn_name}/"
  permissions_boundary = module.acs.role_permissions_boundary.arn
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
  ]
}
