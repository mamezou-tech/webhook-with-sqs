# Webhook Application Module
module "webhook_application" {
  source = "./application"
  prefix = local.prefix
  api_gateway = {
    api_id        = data.aws_apigatewayv2_api.this.id
    execution_arn = data.aws_apigatewayv2_api.this.execution_arn
  }
}
