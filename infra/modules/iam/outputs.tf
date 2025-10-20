output "ci_assume_role_arn" {
  value = aws_iam_role.ci_role.arn
}

output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_execution.arn
}
