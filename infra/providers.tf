provider "aws" {
  region  = "us-east-1"
  profile = "terraform-admin"  
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}