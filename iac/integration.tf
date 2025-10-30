# Integaration of API Gateway
# IAM
data "aws_iam_policy_document" "apigateway_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "sqs_send_only_policy" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = ["${aws_sqs_queue.webhook_queue.arn}"]
  }
}

resource "aws_iam_role" "webhook_event_producer_role" {
  name               = "${local.prefix}-webhook-event-producer-role"
  assume_role_policy = data.aws_iam_policy_document.apigateway_assume_role.json
}

resource "aws_iam_role_policy" "sqs_integration_access_policy" {
  name   = "sqs-integration-access-policy"
  role   = aws_iam_role.webhook_event_producer_role.id
  policy = data.aws_iam_policy_document.sqs_send_only_policy.json
}

resource "aws_iam_role_policies_exclusive" "webhook_event_producer_role_policies" {
  role_name = aws_iam_role.webhook_event_producer_role.name
  policy_names = [
    aws_iam_role_policy.sqs_integration_access_policy.name
  ]
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "webhook_event_producer" {
  description         = "Queue of Webhook Event"
  api_id              = data.aws_apigatewayv2_api.this.id
  integration_type    = "AWS_PROXY"
  integration_subtype = "SQS-SendMessage"
  credentials_arn     = aws_iam_role.webhook_event_producer_role.arn

  request_parameters = {
    "QueueUrl"       = aws_sqs_queue.webhook_queue.url
    "MessageGroupId" = local.message_group_id
    "MessageBody"    = "$request.body"
  }
}

# API Gateway Route
resource "aws_apigatewayv2_route" "webhook_event_route" {
  api_id    = data.aws_apigatewayv2_api.this.id
  route_key = "POST /sqs-hook"
  target    = "integrations/${aws_apigatewayv2_integration.webhook_event_producer.id}"
}
