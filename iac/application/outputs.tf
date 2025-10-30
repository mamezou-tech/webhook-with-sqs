output "application_route" {
  value = split(" ", aws_apigatewayv2_route.webhook_application.route_key)[1]
}
