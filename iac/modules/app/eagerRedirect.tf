module "eager_redirect_lambda_api" {
  source       = "github.com/byu-oit/terraform-aws-lambda-api?ref=v3.0.1"
  app_name     = "${var.cdn_name}-edge-eager-redirect-${var.env}"
  zip_filename = "./../edge-lambdas/eager-redirect/"
  zip_handler  = "index.handler"
  zip_runtime  = "nodejs14.x"
  memory_size = 512
  timeout = 20
  lambda_policies = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  vpc_id                        = module.acs.vpc.id
  public_subnet_ids             = module.acs.public_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  codedeploy_service_role_arn   = module.acs.power_builder_role.arn
}
