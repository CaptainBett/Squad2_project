variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "squad2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.10.1.0/24","10.10.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.10.101.0/24","10.10.102.0/24"]
}
