module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.5.0"
}

resource "aws_iam_policy" "AllowCdnParameterStoreAccess" {
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

resource "aws_iam_policy" "AllowCloudFrontInvalidation" {
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
  name = "${var.cdn_name}-assembler"
}

resource "aws_iam_policy" "AllowAssemblerImageAccess" {
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
resource "aws_iam_role" "EdgeLambdaExecutionRole" {
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
