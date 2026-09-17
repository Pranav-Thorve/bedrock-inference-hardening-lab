data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Failure 1: over-broad execution role. Stages 0 to 3.
data "aws_iam_policy_document" "lambda_broken" {
  statement {
    sid       = "BrokenBroadAccess"
    actions   = ["bedrock:*", "logs:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_broken" {
  count  = local.iam_scoped ? 0 : 1
  name   = "broken-broad-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_broken.json
}

# Failure 1 fixed: stage 4.
data "aws_iam_policy_document" "lambda_scoped" {
  statement {
    sid       = "InvokeOneModel"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = local.bedrock_invoke_resources
  }

  statement {
    sid       = "WriteOwnLogStream"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }
}

resource "aws_iam_role_policy" "lambda_scoped" {
  count  = local.iam_scoped ? 1 : 0
  name   = "scoped-inference-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_scoped.json
}
