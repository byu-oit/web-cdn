data "archive_file" "enhanced_headers_archive" {
  type        = "zip"
  source_dir  = "../../../edge-lambdas/enhanced-headers"
  output_path = "../../../edge-lambdas/enhanced-headers.zip"
}

resource "aws_lambda_function" "enhanced_headers_func" {
  function_name = "${var.cdn_name}-edge-enhanced-headers-${var.env}"
  filename      = "../../../edge-lambdas/enhanced-headers.zip"
  handler       = "index.handler"
  runtime       = "nodejs16.x"
  memory_size   = 128
  timeout       = 20
  role          = aws_iam_role.EdgeLambdaExecutionRole.arn
}
