output "datalake_bucket" {
  description = "S3 bucket to hold streamed DynamoDB events"
  value       = aws_s3_bucket.datalake.bucket
}

output "consumer_lambda" {
  description = "Name of consumer Lambda function"
  value       = aws_lambda_function.ddb_to_s3.function_name
}
