output "proxy_endpoint" {
  description = "Customer-owned capture proxy endpoint URL"
  value       = "${aws_apigatewayv2_api.proxy.api_endpoint}/decision-records"
}

output "proxy_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.proxy.function_name
}

output "proxy_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.proxy.arn
}

output "api_gateway_id" {
  description = "API Gateway HTTP API ID"
  value       = aws_apigatewayv2_api.proxy.id
}

