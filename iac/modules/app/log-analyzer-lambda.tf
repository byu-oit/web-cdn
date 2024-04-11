data "archive_file" "LogAnalyzerSorterFuncLambda" {
  type        = "zip"
  source_dir  = "../../../log-analyzer/sorter-lambda/"
  output_path = "../../../log-analyzer/sorter-lambda.zip"
}

resource "aws_lambda_function" "LogAnalyzerSorterFunc" {
  filename         = data.archive_file.LogAnalyzerSorterFuncLambda.output_path
  function_name    = "${var.cdn_name}-${var.env}-LogAnalyzer-Sorter"
  role             = aws_iam_role.EdgeLambdaExecutionRole.arn
  handler          = "lib/lambda.handler"
  runtime          = "nodejs14.x"
  source_code_hash = base64sha256(data.archive_file.LogAnalyzerSorterFuncLambda.output_path)
  publish          = true
  timeout          = 20
  memory_size      = 128

  environment {
    variables = {
      TZ : "America/Denver"
      LOG_BUCKET : aws_s3_bucket.LogBucket.id
      UNPROCESSED_PREFIX : local.unprocessed_log_prefix
      PREPROCESSED_PREFIX : local.preprocessed_log_prefix
    }
  }
}

resource "aws_lambda_permission" "LogAnalyzerSorterTriggerPermission" {
  statement_id  = "LogAnalyzerSorterTriggerPermission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.LogAnalyzerSorterFunc.arn
  #   principal     = "s3.amazonaws.com"
  principal  = data.aws_caller_identity.current.account_id # TODO figure this out
  source_arn = aws_s3_bucket.LogBucket.arn
}

resource "aws_s3_bucket_notification" "LogAnalyzerSorterFuncTrigger" {
  bucket = aws_s3_bucket.LogBucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.LogAnalyzerSorterFunc.id
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = local.unprocessed_log_prefix
  }

  depends_on = [aws_lambda_permission.LogAnalyzerSorterTriggerPermission]
}
