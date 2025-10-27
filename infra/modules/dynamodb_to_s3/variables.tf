variable "project_prefix" {
  type    = string
  default = "squad2"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ddb_table_arn" {
  description = "ARN of the DynamoDB table to consume (must have stream enabled)"
  type        = string
}

variable "ddb_stream_arn" {
  description = "ARN of the DynamoDB stream (shard stream ARN)"
  type        = string
}

variable "ddb_table_name" {
  description = "DynamoDB table name (for referencing)"
  type        = string
}

variable "lambda_timeout" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
