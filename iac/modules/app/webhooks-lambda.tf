resource "aws_iam_role" "cdn_build_invoker_role" {
  name = "CdnBuildInvokerRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
    ]
  })
  path                 = "/${var.name}/"
  permissions_boundary = module.acs.role_permissions_boundary.arn
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    aws_iam_policy.run_assembler.arn
  ]
}

data "aws_iam_policy_document" "run_assembler_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:RunTask"
    ]
    resources = [
      module.assembler.task_definition.arn
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      module.assembler.task_execution_role.arn,
      module.assembler.task_role.arn
    ]
  }
}

resource "aws_iam_policy" "run_assembler" {
  name        = "run-assembler-task-${var.env}"
  description = "Allows the trigger lambda to start the assembler ecs task"
  policy      = data.aws_iam_policy_document.run_assembler_doc.json
}

resource "aws_lambda_function" "webhook_func" {
  function_name = "${local.app_name}-webhooks"
  role          = aws_iam_role.cdn_build_invoker_role.arn
  package_type  = "Image"
  image_uri     = "${data.aws_ecr_repository.webhooks_repo.repository_url}:${var.image_tag}"
  timeout       = 60
  memory_size   = 128

  environment {
    variables = {
      ASSEMBLER_SECURITY_GROUP_ID = module.assembler.fargate_security_group.id
      ASSEMBLER_SUBNET_IDS        = jsonencode(module.acs.private_subnet_ids)
      TASK_CLUSTER                = module.assembler.new_ecs_cluster.name
      TASK_DEFINITION             = module.assembler.task_definition.id
      CDN_MAIN_CONFIG_REPO        = "byu-oit/web-cdn"
      CDN_MAIN_CONFIG_BRANCH      = var.config_branch
    }
  }
}

resource "aws_api_gateway_rest_api" "webhook_domain" {
  name        = "webhook-domain-gateway"
  description = "CDN WebhookDomain API Gateway"
}

# TODO: change when we deploy to the real domain
resource "aws_api_gateway_domain_name" "webhook_domain" {
  certificate_arn = module.acs.certificate_virginia.arn
  domain_name     = "webhooks.${var.cdn_url}"
  security_policy = "TLS_1_0"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.webhook_domain.id
  parent_id   = aws_api_gateway_rest_api.webhook_domain.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.webhook_domain.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_func.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.webhook_domain.execution_arn}/*/*"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.webhook_domain.id
  resource_id             = aws_api_gateway_resource.proxy.id
  integration_http_method = "POST"
  http_method             = aws_api_gateway_method.proxy_method.http_method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.webhook_func.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.webhook_domain.id
  stage_name  = var.stage_name
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_resource.proxy,
  ]
}

resource "aws_route53_record" "webhooks_a_record" {
  name            = "webhooks"
  type            = "A"
  zone_id         = data.aws_route53_zone.cdn_zone.id
  allow_overwrite = false
  alias {
    name                   = aws_api_gateway_domain_name.webhook_domain.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.webhook_domain.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "webhooks_aaaa_record" {
  name            = "webhooks"
  type            = "AAAA"
  zone_id         = data.aws_route53_zone.cdn_zone.id
  allow_overwrite = false
  alias {
    name                   = aws_api_gateway_domain_name.webhook_domain.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.webhook_domain.cloudfront_zone_id
    evaluate_target_health = false
  }
}

resource "aws_api_gateway_base_path_mapping" "base_path_mapping" {
  api_id      = aws_api_gateway_rest_api.webhook_domain.id
  stage_name  = aws_api_gateway_deployment.deployment.stage_name
  domain_name = aws_api_gateway_domain_name.webhook_domain.domain_name
}
