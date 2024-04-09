module "assembler" {
  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.0.0"

  app_name = "${var.cdn_name}-${var.env}-assembler"

  primary_container_definition = {
    name        = "${var.cdn_name}-${var.env}-assembler"
    image       = "${data.aws_ecr_repository.assembler_ecr_repo.repository_url}:${var.image_tag}" # FIXME: should name be used?
    task_cpu    = 4096
    task_memory = 8192
    environment_variables = { # TODO: Fill in missing refs
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
      aws_iam_policy.AllowCloudFrontInvalidation.arn
    ]
  }

  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
}
