data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/${local.handler_module}.py"
  output_path = "${path.module}/build/${local.handler_module}.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project}-handler"
  retention_in_days = 7
}

resource "aws_lambda_function" "handler" {
  function_name    = "${var.project}-handler"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "${local.handler_module}.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      MODEL_ID  = var.model_id
      LAB_STAGE = tostring(var.lab_stage)
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}
