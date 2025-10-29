variable "project_prefix" {
  type    = string
  default = "squad2"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "datalake_bucket" {
  type        = string
  description = "S3 bucket where raw events are stored (dynamodb->s3 consumer)"
}

variable "events_prefix" {
  type    = string
  default = "events/"
  description = "Prefix under datalake_bucket with JSON event files"
}

variable "output_prefix" {
  type    = string
  default = "personalize/input/"
  description = "Prefix where Glue writes the interactions CSV"
}

variable "glue_worker_type" {
  type    = string
  default = "G.1X"
}

variable "glue_workers" {
  type    = number
  default = 2
}
