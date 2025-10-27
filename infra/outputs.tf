output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "ci_assume_role_arn" {
  value = module.iam.ci_assume_role_arn
}

output "lambda_execution_role_arn" {
  value = module.iam.lambda_execution_role_arn
}

output "frontend_bucket" {
  value = module.s3_cloudfront.bucket_name
}

output "cloudfront_domain" {
  value = module.s3_cloudfront.cloudfront_domain
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution."
  value       = module.s3_cloudfront.cloudfront_distribution_id
}