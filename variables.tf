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
  default     = "us.anthropic.claude-3-haiku-20240307-v1:0"
}
