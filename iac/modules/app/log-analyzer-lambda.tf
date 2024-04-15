
resource "aws_lambda_function" "LogAnalyzerSorterFunc" {
  function_name = "${var.cdn_name}-${var.env}-LogAnalyzer-Sorter"
  role          = aws_iam_role.EdgeLambdaExecutionRole.arn
  package_type  = "Image"
  image_uri     = "${data.aws_ecr_repository.log_sorter_ecr_repo.repository_url}:${var.image_tag}"
  publish       = true
  timeout       = 20
  memory_size   = 128

  environment {
    variables = {
      TZ : "America/Denver"
      LOG_BUCKET : aws_s3_bucket.LogBucket.id
      UNPROCESSED_PREFIX : local.unprocessed_log_prefix
      PREPROCESSED_PREFIX : local.preprocessed_log_prefix
    }
  }
}

# Trigger for Log Bucket to call Sorter/Analyzer Lambda when things are added

resource "aws_lambda_permission" "LogAnalyzerSorterTriggerPermission" {
  statement_id  = "LogAnalyzerSorterTriggerPermission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.LogAnalyzerSorterFunc.function_name
  principal     = "s3.amazonaws.com"
  #   principal  = data.aws_caller_identity.current.account_id # TODO figure this out
  source_arn = aws_s3_bucket.LogBucket.arn
}

resource "aws_s3_bucket_notification" "LogAnalyzerSorterFuncTrigger" {
  bucket = aws_s3_bucket.LogBucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.LogAnalyzerSorterFunc.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = local.unprocessed_log_prefix
  }

  depends_on = [aws_lambda_permission.LogAnalyzerSorterTriggerPermission, aws_s3_bucket.LogBucket]
}
