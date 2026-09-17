# Failure 2 fixed: rate-based rule on the stage, stage 1 and later.
resource "aws_wafv2_web_acl" "this" {
  count       = local.throttled ? 1 : 0
  name        = "${var.project}-acl"
  description = "Rate limit a single source IP against the inference endpoint."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit-per-ip"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit                 = var.waf_rate_limit
        evaluation_window_sec = 300
        aggregate_key_type    = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-acl"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "stage" {
  count        = local.throttled ? 1 : 0
  resource_arn = "arn:aws:apigateway:${var.aws_region}::/restapis/${aws_api_gateway_rest_api.this.id}/stages/${aws_api_gateway_stage.lab.stage_name}"
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}

# Log group name has to start with aws-waf-logs-.
resource "aws_cloudwatch_log_group" "waf" {
  count             = local.throttled ? 1 : 0
  name              = "aws-waf-logs-${var.project}"
  retention_in_days = 7
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count                   = local.throttled ? 1 : 0
  resource_arn            = aws_wafv2_web_acl.this[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
}
