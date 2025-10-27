locals {
  name_prefix = "${var.project_prefix}-events"
}

# Kinesis Data Stream (analytics)
resource "aws_kinesis_stream" "events_stream" {
  count            = var.create_kinesis ? 1 : 0
  name             = "${local.name_prefix}-stream"
  shard_count      = 1
  retention_period = 24
  tags = { Project = var.project_prefix }
}


# DynamoDB Table for user events
resource "aws_dynamodb_table" "user_events" {
  name           = "${local.name_prefix}-dynamo"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  range_key      = "event_time"
  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "event_time"
    type = "N"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
  
  tags = {
    Project = var.project_prefix
  }
}

# IAM role for Lambda
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_prefix}-event-collector-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags = {
    Project = var.project_prefix
  }
}

# Inline policy for Lambda: allow DynamoDB PutItem, Kinesis PutRecord, CloudWatch logs
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid = "DDBAccess"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
      "dynamodb:BatchWriteItem"
    ]
    resources = [
      aws_dynamodb_table.user_events.arn,
      "${aws_dynamodb_table.user_events.arn}/*"
    ]
  }

dynamic "statement" {
  for_each = var.create_kinesis ? [1] : []
  content {
    sid = "KinesisAccess"
    actions = [
      "kinesis:PutRecord",
      "kinesis:PutRecords",
      "kinesis:DescribeStream",
      "kinesis:ListShards"
    ]
    resources = [aws_kinesis_stream.events_stream[0].arn]
  }
}


  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:*:*"]
  }
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name   = "${var.project_prefix}-event-collector-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# Lambda function (code must be provided as a zip file path - see instructions)
resource "aws_lambda_function" "event_collector" {
  filename         = "${path.module}/event_collector.zip" # create zip at this path before terraform apply
  function_name    = "${var.project_prefix}-event-collector"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = var.lambda_timeout
  publish          = true

  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.user_events.name
      KINESIS_STREAM = var.create_kinesis ? aws_kinesis_stream.events_stream[0].name : ""
      REGION = var.aws_region
    }
  }

  tags = {
    Project = var.project_prefix
  }
}

# Grant Lambda permission to be called by API Gateway v2 (HTTP API)
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_collector.arn
  principal     = "apigateway.amazonaws.com"
  # source_arn set later after API is created via interpolation in a separate resource
}

# HTTP API (API Gateway v2)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.project_prefix}-events-api"
  protocol_type = "HTTP"
  tags = {
    Project = var.project_prefix
  }
}

# Integration: Lambda (need the special apigateway ARN format)
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.event_collector.arn}/invocations"
  payload_format_version = "2.0"
  timeout_milliseconds = 30000
}

# Route and stage
resource "aws_apigatewayv2_route" "post_events_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /events"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Now set the lambda permission source_arn (API execution ARN) by updating the permission via a separate resource
resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowExecutionFromHTTPAPI"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_collector.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}


