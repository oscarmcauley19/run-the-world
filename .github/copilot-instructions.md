This repository implements a minimal Strava OAuth MVP (S3 frontend, Lambda backend, DynamoDB storage).

Keep instructions concise and specific to this codebase.

- Big picture
  - Frontend: `frontend/index.html` (static, vanilla JS). Button redirects to `/auth/strava`.
  - Backend: single Lambda at `lambda-src/index.js` handles two routes: `/auth/strava` (redirect to Strava) and `/auth/callback` (exchange code, persist tokens).
  - Infra: Terraform modules under `modules/` and root config in `terraform/`.

- Important files/vars
  - Lambda: `lambda-src/index.js` reads secret ARN from env `STRAVA_SECRET_ARN`, and DynamoDB table name from `USERS_TABLE`. Redirects back to `FRONTEND_URL` env var.
  - Secrets: Terraform module `modules/secrets` expects a Secrets Manager secret named `rtw/strava` by default. The secret JSON should contain STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET, STRAVA_REDIRECT_URI.
  - DynamoDB: `modules/dynamodb` creates `users` table with partition key `strava_athlete_id`.

- Patterns and conventions
  - Single Lambda with simple router: use `event.rawPath` and `event.queryStringParameters` (HTTP API v2). Keep handler small and testable.
  - Secrets are read from Secrets Manager (avoid inline secrets). Prefer creating secret externally and letting the secrets module lookup the ARN.
  - Terraform modules are small and parameterized: pass `aws_region` to modules via `terraform/variables.tf`.

- How to extend
  - To add another backend route, edit `lambda-src/index.js` router and re-deploy the lambda module.
  - To change scopes for Strava, modify the scope value in the `/auth/strava` branch of the handler.

- Helpful examples
  - Token storage shape (DynamoDB `users` table): keys stored are `strava_athlete_id`, `access_token`, `refresh_token`, `expires_at`, `created_at`.
  - Strava exchange endpoint used: `https://www.strava.com/oauth/token` (see handler for exact POST params).

- Dev workflows
  - Creating secrets: use AWS CLI to create `rtw/strava` as described in `terraform/README.md`.
  - Deploy infra: `cd terraform && terraform init && terraform apply`.
  - Upload frontend: `aws s3 sync frontend/ s3://<bucket>` (or add CI step to do this).

Focus on discoverable, actionable guidance only. If additional context is needed (domain names, real client IDs), ask the repo owner rather than inventing values.
