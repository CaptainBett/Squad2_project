variable "project_prefix" {
  type    = string
  default = "squad2"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "lambda_timeout" {
  type    = number
  default = 10
}

variable "create_kinesis" {
  description = "Whether to create a Kinesis stream. Set to false if your account doesn't have Kinesis subscription."
  type        = bool
  default     = false
}
