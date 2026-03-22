# Run The World — MVP

This workspace contains a minimal MVP to implement Strava OAuth login and store user tokens.

## Structure (important files/directories):

- `frontend/` — static site to host on S3 (index.html)
- `lambda-src/` — Lambda function source that handles /auth/strava and /auth/callback
- `modules/` — Terraform modules (frontend, api, lambda, dynamodb, secrets)
- `terraform/` — root Terraform configuration that wires modules together

## Quick dev notes

- Do NOT store secrets in the repository. Two recommended ways to provide the Strava credentials:
  1.  Create the secret in AWS Secrets Manager (preferred) and set `var.strava_secret_name` to the secret name.
      Example (AWS CLI):

      ```bash
      aws secretsmanager create-secret \
      	 --name rtw/strava \
      	 --secret-string '{"STRAVA_CLIENT_ID":"<id>","STRAVA_CLIENT_SECRET":"<secret>","STRAVA_REDIRECT_URI":"https://yourdomain.com/auth/callback"}'
      ```

  2.  Provide the secret JSON as a Terraform variable at apply time (less preferred):

      ```bash
      terraform apply -var='strava_secret_name=rtw/strava' -var='secret_value_json={"STRAVA_CLIENT_ID":"...","STRAVA_CLIENT_SECRET":"...","STRAVA_REDIRECT_URI":"https://..."}'
      ```

- Run `terraform init` then `terraform apply` from the `terraform/` folder.
- The lambda code reads the secret ARN from env var `STRAVA_SECRET_ARN` and the DynamoDB table name from `USERS_TABLE`.
- After Terraform creates the S3 bucket, upload the frontend files:

```bash
# replace <bucket> with the bucket name from `terraform output`
aws s3 sync frontend/ s3://<bucket> --acl private
```

- The Lambda `FRONTEND_URL` env var is used for the final redirect after successful OAuth; set it to your frontend host (CloudFront domain or custom domain).

## Full setup checklist (first-time)

Follow these steps to provision the infrastructure and verify the MVP. Commands assume `aws` CLI and `terraform` are installed and configured.

### Prerequisites (local)

1. AWS account and credentials with permissions to create Lambda, API Gateway v2, IAM, S3, CloudFront, DynamoDB, and Secrets Manager. For initial setup an AdministratorAccess user is easiest; tighten later.
2. Install the AWS CLI and run `aws configure` (or set environment variables).
3. Install Terraform (>= 1.0).
4. (Optional) Node.js 18+ to test or modify Lambda locally.

### A) Create Strava app and record credentials

- Register an application at Strava Developer and note the `STRAVA_CLIENT_ID` and `STRAVA_CLIENT_SECRET`.
- Set the Redirect URI to `https://YOUR_FRONTEND_DOMAIN/auth/callback` (or use `https://<cloudfront>/auth/callback` after deploy).

### B) Store Strava credentials in Secrets Manager (recommended)

Create the secret once (manual/CLI). Example (one-time):

```bash
aws secretsmanager create-secret \
    --name rtw/strava \
    --secret-string '{"STRAVA_CLIENT_ID":"<id>","STRAVA_CLIENT_SECRET":"<secret>","STRAVA_REDIRECT_URI":"https://yourdomain.com/auth/callback"}' \
    --region eu-west-2
```

Verify:

```bash
aws secretsmanager describe-secret --name rtw/strava --region eu-west-2
```

### C) Prepare Terraform

```bash
cd terraform
# Optionally edit variables.tf or pass variables via CLI/TF_VAR_ env vars
```

### D) Dry-run (recommended)

Locally:

```bash
terraform init
terraform plan -out=tfplan
terraform show -no-color tfplan > plan.txt
less plan.txt
```

Or use the GitHub Action dry-run: Actions → deploy → Run workflow → set `dry_run: true` (this runs `terraform plan` and exits without mutating infra).

### E) First apply

Option 1 — locally (recommended if you created the secret manually):

```bash
terraform init
terraform apply -auto-approve
```

Option 2 — via CI (recommended to avoid leaking secrets):

- Add these repository Secrets in GitHub: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `STRAVA_REDIRECT_URI`.
- Trigger the `deploy` workflow (Actions → deploy). The workflow will create/update the Secrets Manager secret (only when not in dry-run), run `terraform apply`, upload the frontend, and invalidate CloudFront (if enabled).

### F) Upload frontend (if not using CI upload)

Get the bucket name from Terraform outputs then sync:

```bash
cd terraform
terraform output -raw frontend_bucket
aws s3 sync ../frontend s3://<bucket-name> --delete
```

If CloudFront is used, invalidate:

```bash
aws cloudfront create-invalidation --distribution-id <dist-id> --paths "/*"
```

### G) Test OAuth flow

- Open your frontend URL and click "Connect with Strava".
- Authorize the app in Strava; you should be redirected back to `FRONTEND_URL` and a record created in DynamoDB `users` table.

## Helpful commands

- Show Terraform outputs:

```bash
cd terraform
terraform output -json
terraform output -raw frontend_bucket
```

- Import an existing secret into Terraform state (if you later want Terraform to manage it):

```bash
terraform import module.secrets.aws_secretsmanager_secret.strava <secret-id-or-arn>
```

- Run only Terraform plan locally:

```bash
terraform init
terraform plan -out=tfplan
terraform show -no-color tfplan > plan.txt
```

## CI dry-run and deploy notes

- The GitHub Actions workflow supports a `dry_run` input. When `dry_run=true` the workflow will only run `terraform plan` and skip secret creation, upload, and invalidation.
- The workflow builds the Strava secret JSON from GitHub Secrets and creates/updates the `rtw/strava` secret via the AWS CLI (keeps secret out of Terraform state).

## Permissions required by CI user

- Secrets Manager: DescribeSecret, CreateSecret, PutSecretValue
- S3: PutObject, DeleteObject, ListBucket for the frontend bucket
- CloudFront: CreateInvalidation
- Terraform infra: IAM, Lambda, API Gateway, DynamoDB, Logs

## Notes and pitfalls

- Prefer creating the secret manually or via CI once; avoid passing secret JSON directly into Terraform variables for production (it ends up in state).
- Use a remote Terraform state backend (S3 + DynamoDB locking) when running Terraform from CI and locally to avoid state divergence.
- For production, consider replacing the CloudFront OAI with the newer OAC + ACM for HTTPS and a custom domain.

If you'd like, I can add an artifact step to the dry-run that uploads `plan.txt` for download, or a small verification script that runs after a deploy to confirm the API and Lambda are reachable.
