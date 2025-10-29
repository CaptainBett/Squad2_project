module "vpc" {
  source = "./modules/vpc"

  project_prefix       = var.project_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "iam" {
  source = "./modules/iam"

  project_prefix = var.project_prefix
}

module "s3_cloudfront" {
  source         = "./modules/s3_cloudfront"
  project_prefix = var.project_prefix
  aws_region     = var.aws_region
  enable_acm     = false # change to true if you want and have a domain
  domain_name    = ""    # set your custom domain if enable_acm = true
  tags = {
    Project = var.project_prefix
  }
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}

module "event_collector" {
  source         = "./modules/event_collector"
  project_prefix = var.project_prefix
  aws_region     = var.aws_region
  create_kinesis = false
}

module "dynamodb_to_s3" {
  source         = "./modules/dynamodb_to_s3"
  project_prefix = var.project_prefix
  aws_region     = var.aws_region

  # pass in the existing table name and stream ARN from event_collector module
  ddb_table_name = module.event_collector.dynamodb_table_name
  ddb_table_arn  = module.event_collector.dynamodb_table_arn
  ddb_stream_arn = module.event_collector.dynamodb_stream_arn
  tags = {
    Project = var.project_prefix
  }
}

module "glue_etl" {
  source           = "./modules/glue_etl"
  project_prefix   = var.project_prefix
  aws_region       = var.aws_region
  datalake_bucket  = module.dynamodb_to_s3.datalake_bucket # or your bucket name
  events_prefix    = "events/"
  output_prefix    = "personalize/input/"
  glue_worker_type = "G.1X"
  glue_workers     = 2
}
