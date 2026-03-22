module "dynamodb" {
  source = "../modules/dynamodb"
  table_name = "users"
}

module "secrets" {
  source = "../modules/secrets"
  secret_name = var.strava_secret_name
  secret_value_json = ""
}

module "lambda" {
  source = "../modules/lambda"
  function_name = "rtw-strava-auth"
  source_dir = "${path.root}/../lambda-src"
  users_table = module.dynamodb.table_name
  secret_arn = module.secrets.secret_arn
  frontend_url = var.frontend_domain
  aws_region = var.aws_region
}

module "api" {
  source = "../modules/api"
  lambda_arn = module.lambda.lambda_arn
  aws_region = var.aws_region
}

module "frontend" {
  source = "../modules/frontend"
  bucket_name = "${var.project_name}-frontend-${random_id.frontend_suffix.hex}"
}

data "aws_caller_identity" "current" {}

resource "random_id" "frontend_suffix" {
  byte_length = 4
}
