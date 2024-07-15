module "assembler" {
  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.0.0"

  app_name    = "${local.app_name}-assembler"
  task_cpu    = 4096
  task_memory = 8192

  primary_container_definition = {
    name  = "${local.app_name}-assembler"
    image = "${data.aws_ecr_repository.assembler_ecr_repo.repository_url}:${var.image_tag}"
    environment_variables = {
      "DESTINATION_S3_BUCKET" = aws_s3_bucket_website_configuration.cdn_content_bucket.id,
      "BUILD_ENV"             = var.env,
      "CDN_HOST"              = var.cdn_url,
    }

    secrets = {
      GITHUB_TOKEN = "/${var.name}/${var.env}/GITHUB_TOKEN"
      GITHUB_USER  = "/${var.name}/${var.env}/GITHUB_USER"
    }
  }

  task_policies = [
    "arn:aws:iam::aws:policy/CloudFrontReadOnlyAccess",
    aws_iam_policy.allow_cloudfront_invalidation.arn,
    aws_iam_policy.allow_builder_access_s3.arn
  ]

  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
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

resource "aws_iam_policy" "allow_builder_access_s3" {
  depends_on = [aws_s3_bucket.cdn_content_bucket]
  name       = "allow_builder_access_s3"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket",
          "s3:PutBucketWebsite",
          "s3:Get*",
          "s3:*",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        "Resource" = [
          aws_s3_bucket.cdn_content_bucket.arn,
          "${aws_s3_bucket.cdn_content_bucket.arn}/*"
        ]
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
        "Resource" : aws_cloudfront_distribution.website_cloudfront.arn
      }
    ]
  })
}
