resource "aws_secretsmanager_secret" "strava" {
  count = var.secret_value_json != "" ? 1 : 0
  name  = var.secret_name
}

resource "aws_secretsmanager_secret_version" "strava_version" {
  count         = var.secret_value_json != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.strava[0].id
  secret_string = var.secret_value_json
}

data "aws_secretsmanager_secret" "existing" {
  count = var.secret_value_json == "" ? 1 : 0
  name  = var.secret_name
}

output "secret_arn" {
  value = var.secret_value_json != "" ? aws_secretsmanager_secret.strava[0].arn : data.aws_secretsmanager_secret.existing[0].arn
}
