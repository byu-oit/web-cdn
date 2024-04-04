variable "configuration_github_repo" {
  type = string
}

variable "configuration_github_branch" {
  type = string
}

data "archive_file" "WebhookFuncLambda" {
  type        = "zip"
  source_dir  = "../../../webhooks/"
  output_path = "../../../webhooks.zip"
}

resource "aws_iam_policy" "CdnBuildInvokerPolicy" {
  name = "AllowBuildInvocation"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "codebuild:StartBuild",
        "Resource" : "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:project/${var.cdn_name}-*-assembler"
      }
    ]
  })
}

resource "aws_api_gateway_rest_api" "tweeter_api_gateway" {
  name = "tweeter-api-gateway"
  description = "tweeter-api-gateway"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

module "WebhookFunc" {
  source       = "github.com/byu-oit/terraform-aws-lambda-api?ref=v3.0.1"
  app_name     = "${var.cdn_name}-webhooks-${var.env}"
  zip_filename = data.archive_file.WebhookFuncLambda.output_path
  zip_handler  = "lambda.handler"
  zip_runtime  = "nodejs14.x"

  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  vpc_id                        = module.acs.vpc.id
  public_subnet_ids             = module.acs.public_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  codedeploy_service_role_arn   = module.acs.power_builder_role.arn
  timeout                       = 60
  use_codedeploy                = false

  environment_variables = {
    CDN_BUILDER_NAME: '??'
    CDN_MAIN_CONFIG_REPO: var.configuration_github_repo
    CDN_MAIN_CONFIG_BRANCH: var.configuration_github_branch
  }

  lambda_policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    aws_iam_policy.CdnBuildInvokerPolicy.arn
  ]
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = aws_lambda_function.queue.arn
}

resource "aws_lambda_function" "WebhookFunc" {
  filename                       = data.archive_file.WebhookFuncLambda.output_path
  function_name                  = "${var.cdn_name}-webhooks-${var.env}"
  role                           = aws_iam_role.CdnBuildInvokerRole.arn
  handler                        = "lambda.handler"
  runtime                        = "nodejs14.x"
  source_code_hash               = base64sha256(data.archive_file.WebhookFuncLambda.output_path)
  publish                        = true
  timeout                        = 60

  environment {
    ECS_TASK_NAME: '??'
    CDN_MAIN_CONFIG_REPO: var.configuration_github_repo
    CDN_MAIN_CONFIG_BRANCH: var.configuration_github_branch
  }
}
