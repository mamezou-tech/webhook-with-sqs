output "apigateway_endpoint" {
  value = data.aws_apigatewayv2_api.this.api_endpoint
}

output "apigateway_id" {
  value = data.aws_apigatewayv2_api.this.id
}

output "queue_url" {
  value = aws_sqs_queue.webhook_queue.url
}

output "queue_arn" {
  value = aws_sqs_queue.webhook_queue.arn
}

output "dlq_url" {
  value = aws_sqs_queue.webhook_dlq.url
}

output "dlq_arn" {
  value = aws_sqs_queue.webhook_dlq.arn
}
