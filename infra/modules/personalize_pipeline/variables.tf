variable "project_prefix" {
  type    = string
  default = "squad2"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "datalake_bucket" {
  description = "S3 bucket that contains raw event JSON files (from ddb->s3 consumer)"
  type        = string
}

variable "datalake_events_prefix" {
  description = "Prefix under the datalake bucket where events are stored"
  type        = string
  default     = "events/"
}

variable "personalize_input_prefix" {
  description = "Prefix where Glue will write CSV files consumed by Personalize"
  type        = string
  default     = "personalize/input/"
}

variable "create_personalize_import" {
  description = "When true, run dataset import -> solution -> campaign (requires CSV present)"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
