data "archive_file" "eager_redirect_func" {
  type        = "zip"
  source_dir  = "../../../edge-lambdas/eager-redirect"
  output_path = "../../../edge-lambdas/eager-redirect.zip"
}

resource "aws_lambda_function" "eager_redirect_func" {
  function_name    = "${var.cdn_name}-edge-eager-redirect-${var.env}"
  filename         = data.archive_file.eager_redirect_func.output_path
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  memory_size      = 512
  timeout          = 20
  role             = aws_iam_role.edge_lambda_execution_role.arn
  publish          = true
  source_code_hash = data.archive_file.eager_redirect_func.output_base64sha256 # forces terraform to push the zip files when they change
}
# ==================== CloudWatch ====================

resource "aws_cloudwatch_log_group" "eager_redirect_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.eager_redirect_func.function_name}"
  retention_in_days = 14
}
