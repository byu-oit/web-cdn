resource "aws_lambda_function" "EnhancedHeadersFunc" {
  function_name = "${var.cdn_name}-edge-enhanced-headers-${var.env}"
  filename      = "./../edge-lambdas/enhanced-headers/index.zip"
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  memory_size   = 128
  timeout       = 20
  role          = aws_iam_role.EdgeLambdaExecutionRole.arn
}
