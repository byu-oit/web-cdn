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

resource "aws_lambda_function" "WebhookFunc" {
  filename         = data.archive_file.WebhookFuncLambda.output_path
  function_name    = "${var.cdn_name}-webhooks-${var.env}"
  role             = aws_iam_role.CdnBuildInvokerRole.arn
  handler          = "lambda.handler"
  runtime          = "nodejs16.x"
  source_code_hash = base64sha256(data.archive_file.WebhookFuncLambda.output_path)
  publish          = true
  timeout          = 60
  memory_size      = 128

  environment {
    variables = {
      ECS_TASK_NAME = "${var.cdn_name}-${var.env}-assembler" # The name of the assembler task we are triggering
    }
  }
}

# WebhookDomain
resource "aws_api_gateway_rest_api" "WebHookDomain" {
  name        = "webhook-domain-gateway"
  description = "CDN WebhookDomain API Gateway"
}

# TODO: change when we deploy to the real domain
resource "aws_api_gateway_domain_name" "WebHookDomain" {
  certificate_arn = module.acs.certificate_virginia.arn
  domain_name     = "webhooks.${local.root_dns_name}"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.WebHookDomain.id
  parent_id   = aws_api_gateway_rest_api.WebHookDomain.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id = aws_api_gateway_rest_api.WebHookDomain.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.WebHookDomain.id
  resource_id             = aws_api_gateway_resource.proxy.id
  integration_http_method = "POST"
  http_method             = aws_api_gateway_method.proxy_method.http_method
  type                    = "AWS"
  uri                     = aws_lambda_function.WebhookFunc.invoke_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.WebHookDomain.id
  stage_name  = var.env
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_resource.proxy,
  ]
}
