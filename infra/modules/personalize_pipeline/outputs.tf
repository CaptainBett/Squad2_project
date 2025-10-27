output "glue_script_s3_key" {
  value = aws_s3_object.glue_script.key
}

output "glue_job_name" {
  value = aws_glue_job.transform_job.name
}

output "personalize_dataset_group_arn" {
  value = aws_personalize_dataset_group.dg.arn
}

output "personalize_interactions_dataset_arn" {
  value = aws_personalize_dataset.interactions.arn
}

output "personalize_import_job_id" {
  value = var.create_personalize_import ? aws_personalize_dataset_import_job.import[0].job_name : ""
}
