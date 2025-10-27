variable "project_prefix" {
  type    = string
  default = "squad2"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "enable_acm" {
  description = "Set true to create an ACM cert for custom domain (requires domain_name)."
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Optional custom domain for the CloudFront distribution (example: demo.example.com). Leave empty to use CloudFront domain."
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
