variable "aws_region" {
  type        = string
  description = "Region for API Gateway, Lambda, and Bedrock."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Tag and name prefix."
  default     = "bedrock-inference-hardening-lab"
}

variable "model_id" {
  type        = string
  description = "Bedrock model or inference profile ID passed to InvokeModel."
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

# 0 nothing fixed, 1 throttle + WAF, 2 exception handling, 3 output filter, 4 IAM scoped.
variable "lab_stage" {
  type        = number
  description = "Which failures are fixed. Matches the attack escalation table in the lab plan."
  default     = 0

  validation {
    condition     = var.lab_stage >= 0 && var.lab_stage <= 4 && floor(var.lab_stage) == var.lab_stage
    error_message = "lab_stage must be an integer from 0 to 4."
  }
}

variable "budget_limit_usd" {
  type        = string
  description = "Monthly cost budget for the account running this lab."
  default     = "10"
}

variable "budget_alert_email" {
  type        = string
  description = "Address that receives budget alerts. Empty means the budget is created without notifications."
  default     = ""
}

variable "waf_rate_limit" {
  type        = number
  description = "Requests per 5 minutes from a single IP before the WAF rate rule blocks."
  default     = 100
}

variable "bedrock_logging_role_arn" {
  type        = string
  description = "Role assumed only to set Bedrock invocation logging, for accounts where an SCP restricts that call. Empty means use the default credentials."
  default     = ""
}
