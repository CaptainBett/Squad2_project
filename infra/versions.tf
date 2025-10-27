terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Require a recent provider that includes Personalize resources.
      version = ">= 5.0"
    }
  }
  required_version = ">= 1.4.0"
}
