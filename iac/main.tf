# SQS
resource "aws_sqs_queue" "webhook_queue" {
  name                        = "${local.webhook_queue_name}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = local.processing_timeout
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.webhook_dlq.arn
    maxReceiveCount     = var.webhook.max_receive_count
  })
}

# DLQ
resource "aws_sqs_queue" "webhook_dlq" {
  name                      = "${local.webhook_queue_name}-dlq.fifo"
  fifo_queue                = true
  message_retention_seconds = var.webhook.dlq_retention_second
}

# Lambda
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

# role for receiving message from SQS
data "aws_iam_policy_document" "sqs_receive_message_policy" {
  statement {
    # actions   = ["sqs:*"]
    actions = [
      "sqs:ReceiveMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = ["${aws_sqs_queue.webhook_queue.arn}"]
  }
}

resource "aws_iam_role" "webhook_event_producer_execution_role" {
  name               = local.webhook_event_producer_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_role_policy" "sqs_receive_message_policy" {
  name   = "sqs-receive-message-policy"
  role   = aws_iam_role.webhook_event_producer_execution_role.id
  policy = data.aws_iam_policy_document.sqs_receive_message_policy.json
}

resource "aws_iam_role_policies_exclusive" "webhook_event_producer_execution_role_policies" {
  role_name = aws_iam_role.webhook_event_producer_execution_role.name
  policy_names = [
    aws_iam_role_policy.sqs_receive_message_policy.name,
  ]
}

resource "aws_iam_role_policy_attachment" "webhook_event_producer_basic_execution_role_attach" {
  role       = aws_iam_role.webhook_event_producer_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# cloudwatch logging for webhook lambda
resource "aws_cloudwatch_log_group" "webhook_event_producer" {
  name              = "/aws/lambda/${local.webhook_event_producer_function_name}"
  retention_in_days = var.log_retention_in_days
}

# webhook event producer lambda function
data "template_file" "webhook_event_producer" {
  template = file(local.webhook_event_producer_source_template)
  vars = {
    log_level         = var.webhook.log_level
    apigw_endpoint    = data.aws_apigatewayv2_api.this.api_endpoint
    message_group_id  = local.message_group_id
    application_route = module.webhook_application.application_route
  }
}

data "archive_file" "webhook_event_producer" {
  type        = "zip"
  output_path = "webhook_event_producer.zip"
  source {
    content  = data.template_file.webhook_event_producer.rendered
    filename = "${local.webhook_event_producer_module_name}.py"
  }
}

resource "aws_lambda_function" "webhook_event_producer" {
  description      = "Webhook Event Producer"
  function_name    = local.webhook_event_producer_function_name
  handler          = "${local.webhook_event_producer_module_name}.lambda_handler"
  filename         = data.archive_file.webhook_event_producer.output_path
  source_code_hash = data.archive_file.webhook_event_producer.output_base64sha256

  role = aws_iam_role.webhook_event_producer_execution_role.arn

  runtime       = var.webhook.runtime
  architectures = ["arm64"]
  timeout       = local.processing_timeout

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.webhook_queue.url
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.webhook_event_producer_basic_execution_role_attach,
    aws_cloudwatch_log_group.webhook_event_producer,
  ]
}

resource "aws_lambda_event_source_mapping" "webhook_event_producer_mapping" {
  event_source_arn = aws_sqs_queue.webhook_queue.arn
  function_name    = aws_lambda_function.webhook_event_producer.function_name
  batch_size       = 1 # 1つのメッセージごとに Lambda 関数を呼び出します
  scaling_config {
    maximum_concurrency = var.webhook.max_concurrency
  }
}
