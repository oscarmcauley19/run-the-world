resource "aws_dynamodb_table" "users" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "strava_athlete_id"

  attribute {
    name = "strava_athlete_id"
    type = "S"
  }
}

output "table_name" {
  value = aws_dynamodb_table.users.name
}
