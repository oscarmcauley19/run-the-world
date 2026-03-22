output "api_endpoint" {
  value = module.api.api_endpoint
  description = "HTTP API endpoint"
}

output "lambda_arn" {
  value = module.lambda.lambda_arn
}

output "frontend_bucket" {
  value = module.frontend.bucket_name
}

output "frontend_cloudfront_domain" {
  value = module.frontend.cloudfront_domain
}

output "frontend_cloudfront_distribution_id" {
  value = module.frontend.cloudfront_distribution_id
}
