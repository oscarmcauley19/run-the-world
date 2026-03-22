Terraform deploy notes — Run The World MVP

Quick steps (local)

1. Create the Strava secret in AWS Secrets Manager (recommended). Replace values below with your real client id/secret and redirect URI:

```bash
aws secretsmanager create-secret \
  --name rtw/strava \
  --secret-string '{"STRAVA_CLIENT_ID":"<id>","STRAVA_CLIENT_SECRET":"<secret>","STRAVA_REDIRECT_URI":"https://your-domain.com/auth/callback"}'
```

2. Initialize Terraform and apply from the `terraform/` folder:

```bash
cd terraform
terraform init
terraform apply
```

Notes:

- The Terraform configuration expects an existing Secrets Manager secret named by `var.strava_secret_name` (default `rtw/strava`). The secrets module supports creating the secret if you pass `-var='secret_value_json=<json>'` but that is not recommended for production because secrets may appear in state or logs.
- After apply, upload the static site files from `frontend/` to the S3 bucket created (or wire up CI to do this). Example:

```bash
aws s3 sync ../frontend s3://<bucket-name> --acl private
```

CI suggestion (GitHub Actions): create the secret using AWS CLI in a pre-step (or store it securely in your CI secrets) and then run Terraform. See `.github/workflows/example-deploy.yml` in the repo for a snippet (not included by default).
