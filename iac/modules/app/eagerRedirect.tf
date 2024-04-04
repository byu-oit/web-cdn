resource "aws_lambda_function" "eager_redirect_func" {
  function_name = "${var.cdn_name}-edge-eager-redirect-${var.env}"
  filename      = "./../edge-lambdas/eager-redirect/"
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  memory_size   = 512
  timeout       = 20
  role          = aws_iam_role.EdgeLambdaExecutionRole.arn
}



