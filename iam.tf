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

# Failure 1: over-broad execution role.
data "aws_iam_policy_document" "lambda_broken" {
  statement {
    sid       = "BrokenBroadAccess"
    actions   = ["bedrock:*", "logs:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_broken" {
  name   = "broken-broad-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_broken.json
}
