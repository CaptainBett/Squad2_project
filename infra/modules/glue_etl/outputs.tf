output "glue_job_name" {
  value = aws_glue_job.transform.name
}

output "glue_script_s3_key" {
  value = aws_s3_object.glue_script.key
}

