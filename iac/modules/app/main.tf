module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.5.0"
}

resource "aws_iam_policy" "allow_cdn_parameter_store_access" {
  name        = "AllowCdnParameterStoreAccess"
  description = "Allows access to CDN parameter store"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:DescribeParameters",
          "ssm:GetParameters"
        ],
        "Resource" : "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.cdn_name}/*"
      }
    ]
  })
}

resource "aws_iam_policy" "allow_cloudfront_invalidation" {
  name        = "AllowCloudFrontInvalidation"
  description = "Allows CloudFront invalidation"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ],
        "Resource" : "*"
      }
    ]
  })
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


resource "aws_iam_policy" "allow_assembler_image_access" {
  name        = "AllowAssemblerImageAccess"
  description = "Allows access to Assembler images"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage"
        ],
        "Resource" : data.aws_ecr_repository.assembler_ecr_repo.arn
      }
    ]
  })
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
