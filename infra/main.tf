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
