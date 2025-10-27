output "api_endpoint" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "ddb_table" {
  value = aws_dynamodb_table.user_events.name
}

output "kinesis_stream" {
  # Use the one() function to safely access the single instance
  # from a resource list created with 'count'
  value = one(aws_kinesis_stream.events_stream[*].name)
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.user_events.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.user_events.arn
}

output "dynamodb_stream_arn" {
  value = aws_dynamodb_table.user_events.stream_arn
}
