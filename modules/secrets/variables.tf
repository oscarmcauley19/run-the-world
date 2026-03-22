variable "secret_name" {
  type = string
}

variable "secret_value_json" {
  type = string
  # No default here: provide the secret JSON via a secure mechanism.
  # Recommended approaches:
  # 1) Create the secret in AWS Secrets Manager manually (or via CLI) and pass its name
  #    to this module by setting `secret_value_json` using `terraform apply -var='secret_value_json=<json>'`.
  # 2) Use a separate pipeline or parameter store to inject the secret value into Terraform variables
  #    (avoid committing secrets into the repo).
  # Expected JSON shape (example):
  # {"STRAVA_CLIENT_ID":"<id>","STRAVA_CLIENT_SECRET":"<secret>","STRAVA_REDIRECT_URI":"https://yourdomain.com/auth/callback"}
}