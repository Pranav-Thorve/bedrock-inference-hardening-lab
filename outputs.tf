output "invoke_url" {
  description = "POST URL for the inference API."
  value       = "${aws_api_gateway_stage.lab.invoke_url}/invoke"
}

output "lab_stage" {
  description = "0 nothing fixed, 1 throttle and WAF, 2 exception handling, 3 output filter, 4 IAM scoped."
  value       = var.lab_stage
}

output "lambda_function_name" {
  value = aws_lambda_function.handler.function_name
}

output "lambda_handler_module" {
  description = "Which handler variant is deployed at this stage."
  value       = local.handler_module
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "lambda_log_group" {
  value = aws_cloudwatch_log_group.lambda.name
}

output "apigw_access_log_group" {
  description = "Request-level evidence: source IP, status, latency, throttle and WAF outcome."
  value       = aws_cloudwatch_log_group.apigw_access.name
}

output "bedrock_invocation_log_group" {
  description = "Prompt and completion evidence for the stage 2 and 3 injection attempts."
  value       = aws_cloudwatch_log_group.bedrock_invocations.name
}

output "waf_log_group" {
  description = "WAF rate-rule decisions. Empty before stage 1."
  value       = local.throttled ? aws_cloudwatch_log_group.waf[0].name : ""
}

output "cloudtrail_bucket" {
  description = "CloudTrail delivery bucket, multi-region, Bedrock data events on."
  value       = aws_s3_bucket.trail.id
}

output "api_key" {
  description = "x-api-key header value. Empty before stage 1."
  value       = local.throttled ? aws_api_gateway_api_key.caller[0].value : ""
  sensitive   = true
}

output "model_id" {
  value = var.model_id
}

output "bedrock_invoke_resources" {
  description = "Exactly what the stage 4 scoped policy allows."
  value       = local.bedrock_invoke_resources
}
