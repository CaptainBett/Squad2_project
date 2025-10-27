locals {
  name_prefix = "${var.project_prefix}-personalize"
}

# Upload Glue script to S3 so Glue job can use it
resource "random_id" "script_suffix" {
  byte_length = 3
}

resource "aws_s3_object" "glue_script" {
  bucket = var.datalake_bucket
  key    = "${var.personalize_input_prefix}glue_scripts/transform_events_${random_id.script_suffix.hex}.py"
  source = "${path.module}/glue_script.py"
  etag   = filemd5("${path.module}/glue_script.py")
}

# IAM role for Glue
data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_role" {
  name               = "${local.name_prefix}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "glue_policy" {
  statement {
    sid = "S3Access"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      data.aws_s3_bucket.datalake.arn,
      # defined below via data
      "${data.aws_s3_bucket.datalake.arn}/*"
    ]
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

  statement {
    sid = "GlueCatalog"
    actions = [
      "glue:CreateDatabase",
      "glue:GetDatabase",
      "glue:GetTable",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:GetTableVersion",
      "glue:BatchCreatePartition",
      "glue:GetPartitions"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "glue_role_policy" {
  name   = "${local.name_prefix}-glue-policy"
  role   = aws_iam_role.glue_role.id
  policy = data.aws_iam_policy_document.glue_policy.json
}

# Data source: get bucket ARN
data "aws_s3_bucket" "datalake" {
  bucket = var.datalake_bucket
}

# helper local for bucket arn
resource "null_resource" "datalake_bucket_arn_helper" {
  # nothing to provision; used to expose arn in interpolation
  triggers = { bucket = var.datalake_bucket }
}

# create local variable referencing bucket arn
# (we use the data.aws_s3_bucket.datalake.arn in the policy via interpolation below)
# Terraform HCL requires the actual value inline; so we'll use a data resource above.

# Glue job
resource "aws_glue_job" "transform_job" {
  name     = "${local.name_prefix}-transform-events"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.datalake_bucket}/${aws_s3_object.glue_script.key}"
  }

  default_arguments = {
    "--job-language"    = "python"
    "--datalake_bucket" = var.datalake_bucket
    "--events_prefix"   = var.datalake_events_prefix
    "--output_prefix"   = var.personalize_input_prefix
    "--TempDir"         = "s3://${var.datalake_bucket}/${var.personalize_input_prefix}glue_temp/"
  }

  max_retries       = 1
  glue_version      = "3.0"
  number_of_workers = 2
  worker_type       = "G.1X"
  timeout           = 60
  tags              = var.tags
}

# Personalize IAM role: allow Personalize to read the CSV in S3 for import
data "aws_iam_policy_document" "personalize_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["personalize.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "personalize_role" {
  name               = "${local.name_prefix}-personalize-role"
  assume_role_policy = data.aws_iam_policy_document.personalize_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "personalize_policy" {
  statement {
    sid = "ReadFromS3"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.datalake_bucket}",
      "arn:aws:s3:::${var.datalake_bucket}/*"
    ]
  }
}

resource "aws_iam_role_policy" "personalize_role_policy" {
  name   = "${local.name_prefix}-personalize-policy"
  role   = aws_iam_role.personalize_role.id
  policy = data.aws_iam_policy_document.personalize_policy.json
}

# PERSONALIZE: dataset group
resource "aws_personalize_dataset_group" "dg" {
  name = "${local.name_prefix}-dg"
  tags = var.tags
}

# Personalize schema for interactions
# Schema in JSON: we define fields userId, itemId, timestamp
resource "aws_personalize_schema" "interactions_schema" {
  name = "${local.name_prefix}-interactions-schema"

  schema = <<JSON
{
  "type": "record",
  "name": "Interactions",
  "namespace": "com.squad2.personalize",
  "fields": [
    {"name":"USER_ID","type":"string"},
    {"name":"ITEM_ID","type":"string"},
    {"name":"TIMESTAMP","type":"long"}
  ],
  "version": "1.0"
}
JSON
}

# Personalize dataset (INTERACTIONS)
resource "aws_personalize_dataset" "interactions" {
  dataset_type      = "INTERACTIONS"
  dataset_group_arn = aws_personalize_dataset_group.dg.arn
  name              = "${local.name_prefix}-interactions"
  schema_arn        = aws_personalize_schema.interactions_schema.arn
}

# Optionally create dataset import job if user flips flag to true
resource "aws_personalize_dataset_import_job" "import" {
  count = var.create_personalize_import ? 1 : 0

  job_name    = "${local.name_prefix}-import"
  dataset_arn = aws_personalize_dataset.interactions.arn
  role_arn    = aws_iam_role.personalize_role.arn

  data_source {
    data_location = "s3://${var.datalake_bucket}/${var.personalize_input_prefix}interactions.csv"
  }

  tags = var.tags
}

# Solution (recipe: USER_PERSONALIZATION recommended for general personalization)
resource "aws_personalize_solution" "solution" {
  count = var.create_personalize_import ? 1 : 0

  name              = "${local.name_prefix}-solution"
  dataset_group_arn = aws_personalize_dataset_group.dg.arn
  perform_auto_ml   = false
  perform_hpo       = false
  recipe_arn        = "arn:aws:personalize:::recipe/aws-user-personalization"
}

# Create solution version (train) — will take time
resource "aws_personalize_solution_version" "solution_version" {
  count = var.create_personalize_import ? 1 : 0

  solution_arn = aws_personalize_solution.solution[0].arn

  training_mode = "FULL"
  tags          = var.tags
}

# Campaign to expose realtime recommendations
resource "aws_personalize_campaign" "campaign" {
  count = var.create_personalize_import ? 1 : 0

  name                 = "${local.name_prefix}-campaign"
  solution_version_arn = aws_personalize_solution_version.solution_version[0].arn
  min_provisioned_tps  = 1
  tags                 = var.tags
}
