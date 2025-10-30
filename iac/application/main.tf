## Dummy Webhook Application
# IAM
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "lambda_invoke_function_policy" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "cloudwatch_logs_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect    = "Allow"
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role" "webhook_application_role" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_role_policy" "webhook_application_execution_policy" {
  name   = "${local.function_name}-execution-policy"
  role   = aws_iam_role.webhook_application_role.id
  policy = data.aws_iam_policy_document.lambda_invoke_function_policy.json
}

resource "aws_iam_role_policy" "webhook_application_logging_policy" {
  name   = "${local.function_name}-logging-policy"
  role   = aws_iam_role.webhook_application_role.id
  policy = data.aws_iam_policy_document.cloudwatch_logs_policy.json
}

resource "aws_iam_role_policies_exclusive" "webhook_application_role_policies" {
  role_name = aws_iam_role.webhook_application_role.name
  policy_names = [
    aws_iam_role_policy.webhook_application_execution_policy.name,
    aws_iam_role_policy.webhook_application_logging_policy.name,
  ]
}

# CloudWatch
resource "aws_cloudwatch_log_group" "webhook_application" {
  name = "/aws/lambda/${local.function_name}"
}

# Lambda
data "archive_file" "webhook_application" {
  type        = "zip"
  source_file = "${path.module}/${local.source_path}"
  output_path = "${local.module_name}.zip"
}

resource "aws_lambda_function" "webhook_application" {
  description      = "Dummy Webhook Application"
  function_name    = local.function_name
  handler          = "${local.module_name}.lambda_handler"
  filename         = data.archive_file.webhook_application.output_path
  source_code_hash = data.archive_file.webhook_application.output_base64sha256

  role = aws_iam_role.webhook_application_role.arn

  runtime = var.application.runtime
  timeout = var.application.timeout

  depends_on = [
    aws_cloudwatch_log_group.webhook_application
  ]
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "webhook_application" {
  description            = "Webhook of Dummy Application"
  api_id                 = var.api_gateway.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.webhook_application.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_lambda_permission" "webhook_application" {
  statement_id  = "AllowAPIGatewayWebhookApplication"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_application.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway.execution_arn}/*/*"
}

# API Gateway Route
resource "aws_apigatewayv2_route" "webhook_application" {
  api_id    = var.api_gateway.api_id
  route_key = "POST /application-hook"
  target    = "integrations/${aws_apigatewayv2_integration.webhook_application.id}"
}
