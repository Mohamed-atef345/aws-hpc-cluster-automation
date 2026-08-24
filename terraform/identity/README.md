# Persistent project identity

This root module creates the project's persistent EC2 roles, instance profiles,
GitHub Actions deployment role, and associated least-privilege policies. It
references the GitHub OIDC provider that already exists in the AWS account.

This stack has a separate S3 state key and must not be destroyed when the
disposable HPC lab is torn down.

Before planning, copy `terraform.tfvars.example` to `terraform.tfvars` and
replace `github_oidc_subject` with the exact claim emitted by the repository.

```bash
terraform init -reconfigure
terraform fmt -recursive
terraform validate
terraform plan
```
