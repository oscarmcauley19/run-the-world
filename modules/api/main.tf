resource "aws_apigatewayv2_api" "http" {
  name          = "rtw-http-api"
  protocol_type = "HTTP"
}

data "aws_caller_identity" "current" {}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.http.id
  integration_type   = "AWS_PROXY"
  # For HTTP API, the integration_uri must be the API Gateway-Lambda invocation path format
  integration_uri    = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.lambda_arn}/invocations"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "auth_strava" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /auth/strava"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "auth_callback" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /auth/callback"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arn
  principal     = "apigateway.amazonaws.com"
  # Restrict invoke permission to this HTTP API execution ARN
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.http.id}/*/GET/*"
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.http.api_endpoint
}
