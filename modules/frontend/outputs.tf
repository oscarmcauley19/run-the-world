output "cloudfront_distribution_id" {
  # If CloudFront distribution is not created (count = 0) return empty string
  value = length(aws_cloudfront_distribution.cdn) > 0 ? aws_cloudfront_distribution.cdn[0].id : ""
}
