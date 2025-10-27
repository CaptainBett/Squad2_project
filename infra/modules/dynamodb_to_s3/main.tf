locals {
  name_prefix = "${var.project_prefix}-ddb-to-s3"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket to store batched event files (datalake)
# --- MODIFIED ---
# Removed versioning and server_side_encryption_configuration blocks
resource "aws_s3_bucket" "datalake" {
  bucket        = "${var.project_prefix}-events-datalake-${random_id.bucket_suffix.hex}"
  force_destroy = false

  tags = merge({
    Name = "${var.project_prefix}-events-datalake"
  }, var.tags)
}

# --- ADDED ---
# Extracted versioning into its own resource
resource "aws_s3_bucket_versioning" "datalake_versioning" {
  bucket = aws_s3_bucket.datalake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- ADDED ---
# Extracted encryption into its own resource
resource "aws_s3_bucket_server_side_encryption_configuration" "datalake_sse" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# IAM role for the consumer Lambda
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "consumer_role" {
  name               = "${var.project_prefix}-ddb-consumer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

# Inline policy for Lambda to write to S3 and CloudWatch
data "aws_iam_policy_document" "consumer_policy" {
  statement {
    sid = "AllowS3Put"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.datalake.arn,
      "${aws_s3_bucket.datalake.arn}/*"
    ]
  }

  statement {
    sid = "AllowLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/*"]
  }

  # --- ADDED ---
  # Permissions to read from the DynamoDB stream, as required by the event source mapping
  statement {
    sid = "AllowReadDynamoDBStream"
    actions = [
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeStream",
      "dynamodb:ListStreams"
    ]
    # This policy is attached to the Lambda, which needs to read from the stream
    resources = [var.ddb_stream_arn]
  }
}

resource "aws_iam_role_policy" "consumer_role_policy" {
  name   = "${var.project_prefix}-ddb-consumer-policy"
  role   = aws_iam_role.consumer_role.id
  policy = data.aws_iam_policy_document.consumer_policy.json
}

# Lambda function (consumer)
resource "aws_lambda_function" "ddb_to_s3" {
  filename      = "${path.module}/ddb_to_s3.zip" # create this zip (see instructions)
  function_name = "${var.project_prefix}-ddb-to-s3-consumer"
  role          = aws_iam_role.consumer_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = var.lambda_timeout
  publish       = true

  environment {
    variables = {
      BUCKET = aws_s3_bucket.datalake.bucket
      REGION = var.aws_region
    }
  }

  tags = var.tags
}

# Event source mapping: DynamoDB stream -> Lambda
resource "aws_lambda_event_source_mapping" "ddb_stream_mapping" {
  event_source_arn       = var.ddb_stream_arn
  function_name          = aws_lambda_function.ddb_to_s3.arn
  starting_position      = "TRIM_HORIZON"
  batch_size             = 100
  enabled                = true
  maximum_retry_attempts = 2
}