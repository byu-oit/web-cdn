module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.5.0"
}

## AccountBucket
#resource "aws_s3_bucket" "AccountBucket" {
#  bucket = "${var.cdn_name}-infra-and-logs-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
#}
#
#resource "aws_s3_bucket_public_access_block" "default" {
#  bucket                  = aws_s3_bucket.AccountBucket.id
#  block_public_acls       = true
#  block_public_policy     = true
#  ignore_public_acls      = true
#  restrict_public_buckets = true
#}

# CdnBuilderRole
resource "aws_iam_role" "CdnBuilderRole" {
  name = "CdnBuilderRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codebuild.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  path                 = "/${var.cdn_name}/"
  permissions_boundary = module.acs.role_permissions_boundary.arn
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudFrontReadOnlyAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
  ]
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
        "Resource" : "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.cdn_name}.*"
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

resource "aws_iam_role_policy_attachment" "AllowCdnParameterStoreAccessAttachment" {
  role       = aws_iam_role.CdnBuilderRole.name
  policy_arn = aws_iam_policy.AllowCdnParameterStoreAccess.arn
}

resource "aws_iam_role_policy_attachment" "AllowCloudFrontInvalidationAttachment" {
  role       = aws_iam_role.CdnBuilderRole.name
  policy_arn = aws_iam_policy.AllowCloudFrontInvalidation.arn
}

resource "aws_iam_role_policy_attachment" "AllowAssemblerImageAccessAttachment" {
  role       = aws_iam_role.CdnBuilderRole.name
  policy_arn = aws_iam_policy.AllowAssemblerImageAccess.arn
}

# CdnBuildInvokerRole TODO start ecs task
#resource "aws_iam_role" "CdnBuildInvokerRole" {
#  name = "CdnBuildInvokerRole"
#  assume_role_policy = jsonencode({
#    "Version" : "2012-10-17",
#    "Statement" : [
#      {
#        "Effect" : "Allow",
#        "Principal" : {
#          "Service" : "lambda.amazonaws.com"
#        },
#        "Action" : "sts:AssumeRole"
#      },
#      {
#        "Effect" : "Allow",
#        "Action" : "codebuild:StartBuild",
#        "Resource" : "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:project/${var.cdn_name}-*-assembler"
#      }
#    ]
#  })
#  path                 = "/${var.cdn_name}/"
#  permissions_boundary = module.acs.role_permissions_boundary.arn
#  managed_policy_arns = [
#    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
#  ]
#}

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
