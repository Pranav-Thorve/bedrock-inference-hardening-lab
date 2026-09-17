data "aws_caller_identity" "current" {}

locals {
  tags = {
    Project   = var.project
    LabStage  = tostring(var.lab_stage)
    ManagedBy = "terraform"
  }

  account_id = data.aws_caller_identity.current.account_id

  throttled     = var.lab_stage >= 1
  handler_leaks = var.lab_stage <= 1
  iam_scoped    = var.lab_stage >= 4

  handler_module = var.lab_stage <= 1 ? "handler_stage0" : (var.lab_stage == 2 ? "handler_stage2" : "handler_stage3")

  # A "us." inference profile routes to foundation models in several regions,
  # so a scoped policy has to allow the profile ARN plus every backing model ARN.
  uses_inference_profile = startswith(var.model_id, "us.")
  foundation_model_id    = local.uses_inference_profile ? trimprefix(var.model_id, "us.") : var.model_id
  inference_regions      = local.uses_inference_profile ? ["us-east-1", "us-east-2", "us-west-2"] : [var.aws_region]

  inference_profile_arns = local.uses_inference_profile ? [
    "arn:aws:bedrock:${var.aws_region}:${local.account_id}:inference-profile/${var.model_id}"
  ] : []

  foundation_model_arns = [
    for r in local.inference_regions : "arn:aws:bedrock:${r}::foundation-model/${local.foundation_model_id}"
  ]

  bedrock_invoke_resources = concat(local.inference_profile_arns, local.foundation_model_arns)
}
