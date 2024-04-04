data "archive_file" "eager_redirect_func" {
  type        = "zip"
  source_dir  = "../../../edge-lambdas/eager-redirect"
  output_path = "../../../edge-lambdas/eager-redirect.zip"
}

resource "aws_lambda_function" "eager_redirect_func" {
  function_name = "${var.cdn_name}-edge-eager-redirect-${var.env}"
  filename      = data.archive_file.eager_redirect_func.output_path
  handler       = "index.handler"
  runtime       = "nodejs16.x"
  memory_size   = 512
  timeout       = 20
  role          = aws_iam_role.EdgeLambdaExecutionRole.arn
}



