provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.tags
  }
}

# The sandboxes OU carries an SCP that denies PutModelInvocationLoggingConfiguration
# for every principal except one break-glass role, so that single call is made
# through it. Leave bedrock_logging_role_arn empty in accounts without that SCP.
provider "aws" {
  alias  = "bedrock_logging"
  region = var.aws_region

  dynamic "assume_role" {
    for_each = var.bedrock_logging_role_arn == "" ? [] : [1]
    content {
      role_arn     = var.bedrock_logging_role_arn
      session_name = "terraform-bedrock-invocation-logging"
    }
  }

  default_tags {
    tags = local.tags
  }
}
