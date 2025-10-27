resource "aws_athena_database" "events_db" {
  name   = "squad2_events_db"
  bucket = var.datalake_bucket
}

output "athena_database_name" {
  value = aws_athena_database.events_db.name
}
