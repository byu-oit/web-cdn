resource "aws_lambda_function" "eager_redirect_func" {
  function_name = "${var.cdn_name}-edge-eager-redirect-${var.env}"
  role          = aws_iam_role.edge_lambda_execution_role.arn
  package_type  = "Image"
  image_uri     = "${data.aws_ecr_repository.eager_redirect_ecr_repo.repository_url}:${var.image_tag}"
  publish       = true
  memory_size   = 512
  timeout       = 20
}

# ==================== CloudWatch ====================

resource "aws_cloudwatch_log_group" "eager_redirect_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.eager_redirect_func.function_name}"
  retention_in_days = 14
}
