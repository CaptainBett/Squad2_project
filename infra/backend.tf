terraform {
  required_version = ">= 1.4.0"

  backend "s3" {
    bucket   = "squad2-terraform-state-sam" 
    key      = "squad2/staging/terraform.tfstate"
    region   = "us-east-1"
    encrypt  = true
    use_lockfile = true
  }
}
