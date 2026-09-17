# Failure 2 at stage 0: no usage plan, no API key, no WAF, no authorizer.
resource "aws_api_gateway_rest_api" "this" {
  name        = var.project
  description = "Bedrock inference front door for the hardening lab."
}

resource "aws_api_gateway_resource" "invoke" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "invoke"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.invoke.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = local.throttled
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.invoke.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.handler.invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_method.post.id,
      aws_api_gateway_integration.lambda.id,
      local.throttled,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.lambda]
}

resource "aws_cloudwatch_log_group" "apigw_access" {
  name              = "/aws/apigateway/${var.project}"
  retention_in_days = 7
}

resource "aws_api_gateway_stage" "lab" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = "lab"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      path           = "$context.path"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      latency        = "$context.responseLatency"
      apiKeyId       = "$context.identity.apiKeyId"
      wafResponse    = "$context.waf.status"
      throttled      = "$context.error.messageString"
    })
  }

  depends_on = [aws_api_gateway_account.this]
}

# Execution logging on every method. Data trace stays off: it would write request
# and response bodies, including the stage 0 credential leak, into CloudWatch.
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.lab.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false
    throttling_rate_limit  = local.throttled ? 5 : -1
    throttling_burst_limit = local.throttled ? 10 : -1
  }
}

# Failure 2 fixed: stage 1 and later.
resource "aws_api_gateway_api_key" "caller" {
  count = local.throttled ? 1 : 0
  name  = "${var.project}-caller"
}

resource "aws_api_gateway_usage_plan" "this" {
  count = local.throttled ? 1 : 0
  name  = "${var.project}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.lab.stage_name
  }

  throttle_settings {
    rate_limit  = 5
    burst_limit = 10
  }

  quota_settings {
    limit  = 200
    period = "DAY"
  }
}

resource "aws_api_gateway_usage_plan_key" "caller" {
  count         = local.throttled ? 1 : 0
  key_id        = aws_api_gateway_api_key.caller[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.this[0].id
}
