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
  source       = "./modules/s3_cloudfront"
  project_prefix = var.project_prefix
  aws_region     = var.aws_region
  enable_acm     = false      # change to true if you want and have a domain
  domain_name    = ""         # set your custom domain if enable_acm = true
  tags = {
    Project = var.project_prefix
  }
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}