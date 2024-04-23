data "archive_file" "enhanced_header_func" {
  type        = "zip"
  source_dir  = "../../../edge-lambdas/enhanced-headers"
  output_path = "../../../edge-lambdas/enhanced-headers.zip"
}

resource "aws_lambda_function" "enhanced_headers_func" {
  function_name    = "${local.app_name}-edge-enhanced-headers"
  filename         = data.archive_file.enhanced_header_func.output_path
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  memory_size      = 128
  timeout          = 20
  role             = aws_iam_role.edge_lambda_execution_role.arn
  publish          = true
  source_code_hash = data.archive_file.enhanced_header_func.output_base64sha256 # forces terraform to push the zip files when they change
}

# ==================== CloudWatch ====================
resource "aws_cloudwatch_log_group" "enhanced_headers_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.enhanced_headers_func.function_name}"
  retention_in_days = 14
}
