# 既存想定のものに対する定義
# API Gateway
data "aws_apigatewayv2_apis" "this" {
  protocol_type = "HTTP"
  name          = var.apigw_name
}

data "aws_apigatewayv2_api" "this" {
  api_id = one(data.aws_apigatewayv2_apis.this.ids)
}
