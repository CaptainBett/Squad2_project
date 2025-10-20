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
