locals { name_prefix = "${var.project_prefix}-glue-etl" }

resource "random_id" "script_suffix" { byte_length = 3 }

# Upload glue script
resource "aws_s3_object" "glue_script" {
  bucket = var.datalake_bucket
  key    = "${var.output_prefix}glue_scripts/transform_events_${random_id.script_suffix.hex}.py"
  source = "${path.module}/glue_script.py"
  etag   = filemd5("${path.module}/glue_script.py")
}

data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
       type = "Service" 
       identifiers = ["glue.amazonaws.com"]
        }
  }
}

resource "aws_iam_role" "glue_role" {
  name               = "${local.name_prefix}-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

data "aws_iam_policy_document" "glue_policy" {
  statement {
    sid = "S3Access"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.datalake_bucket}",
      "arn:aws:s3:::${var.datalake_bucket}/*"
    ]
  }

  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:/aws-glue/*"]
  }

  statement {
    sid = "GlueCatalog"
    actions = [
      "glue:CreateDatabase",
      "glue:GetDatabase",
      "glue:CreateTable",
      "glue:GetTable",
      "glue:BatchCreatePartition"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "glue_role_policy" {
  role   = aws_iam_role.glue_role.id
  policy = data.aws_iam_policy_document.glue_policy.json
}

resource "aws_glue_job" "transform" {
  name     = "${local.name_prefix}-transform"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.datalake_bucket}/${aws_s3_object.glue_script.key}"
  }

  default_arguments = {
    "--datalake_bucket" = var.datalake_bucket
    "--events_prefix"   = var.events_prefix
    "--output_prefix"   = var.output_prefix
    "--TempDir"         = "s3://${var.datalake_bucket}/${var.output_prefix}glue_temp/"
  }

  glue_version      = "3.0"
  max_retries       = 1
  number_of_workers = var.glue_workers
  worker_type       = var.glue_worker_type
  timeout           = 60
  tags = {
    Project = var.project_prefix
  }
}

