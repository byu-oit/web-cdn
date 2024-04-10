module "assembler" {
  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.0.0"

  app_name    = "${var.cdn_name}-${var.env}-assembler"
  task_cpu    = 4096
  task_memory = 8192

  primary_container_definition = {
    name  = "${var.cdn_name}-${var.env}-assembler"
    image = "${data.aws_ecr_repository.assembler_ecr_repo.repository_url}:${var.image_tag}" # FIXME: should name be used?
    environment_variables = {                                                               # TODO: Fill in missing refs
      "DESTINATION_S3_BUCKET" = aws_s3_bucket_website_configuration.CdnContentBucket.id,
      "BUILD_ENV"             = var.env,
      "CDN_HOST"              = "${var.cdn_name}-${var.env}.${local.root_dns_name}",
    }

    secrets = {
      GITHUB_TOKEN = "/${var.cdn_name}/${var.env}/github.token"
      GITHUB_USER  = "/${var.cdn_name}/${var.env}/github.user"
    }

    task_policies = [
      "arn:aws:iam::aws:policy/CloudFrontReadOnlyAccess",
      aws_iam_policy.AllowCloudFrontInvalidation.arn,
      aws_iam_policy.allow_builder_access_s3.arn
    ]
  }

  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
}

resource "aws_iam_policy" "allow_builder_access_s3" {
  depends_on = [aws_s3_bucket.CdnContentBucket]
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
          aws_s3_bucket.CdnContentBucket.arn,
          "${aws_s3_bucket.CdnContentBucket.arn}/*"
        ]
      }
    ]
  })
}
#resource "aws_iam_policy" "allow_builder_access_s3_objects" {
#  depends_on = [aws_s3_bucket.CdnContentBucket]
#  name       = "allow_builder_access_s3_objects"
#  policy = jsonencode({
#    "Version" : "2012-10-17",
#    "Statement" : [
#      {
#        "Effect" : "Allow",
#        "Action" : [
#          "s3:*",
#          "s3:PutObject",
#          "s3:PutObjectAcl"
#        ],
#        "Resource" : "${aws_s3_bucket.CdnContentBucket.arn}/*"
#      }
#    ]
#  })
#}
