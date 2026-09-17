output "invoke_url" {
  description = "Unauthenticated POST URL for the broken inference API."
  value       = "${aws_api_gateway_stage.lab.invoke_url}/invoke"
}

output "lambda_function_name" {
  value = aws_lambda_function.handler.function_name
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "lambda_log_group" {
  value = aws_cloudwatch_log_group.lambda.name
}

output "model_id" {
  value = var.model_id
}

output "crash_example" {
  description = "POST body that trips Failure 3 and dumps Lambda environment credentials."
  value       = "curl -sS -X POST \"$INVOKE_URL\" -H 'Content-Type: application/json' -d '{\"prompt\":\"__crash__\"}'"
}
