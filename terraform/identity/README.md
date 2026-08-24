# Persistent project identity

This root module creates the project's persistent EC2 roles, instance profiles,
Secrets Manager containers, GitHub Actions deployment role, and associated
least-privilege policies. It references the GitHub OIDC provider that already
exists in the AWS account. Secret values are populated outside Terraform so
they are never stored in Terraform state.

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

## Secret values

Terraform creates these empty secret containers only:

- `HPCSlurmFreeIPA/freeipa/credentials`
- `HPCSlurmFreeIPA/slurm/munge`
- `HPCSlurmFreeIPA/slurm/database`

Populate their values outside Terraform, preferably through the AWS Secrets
Manager console. Do not add `aws_secretsmanager_secret_version` resources or
commit secret JSON files because doing so would place credentials in Terraform
state or Git history.

The module uses `recovery_window_in_days = 0` by default. Terraform therefore
requests immediate, unrecoverable deletion when a secret is removed from this
stack. This is appropriate for this cost-focused lab, but any required value
must be copied or rotated before deleting its container.

The expected JSON shapes are:

```json
{"admin_password":"...","directory_manager_password":"..."}
```

```json
{"munge_key_base64":"..."}
```

```json
{"database_name":"slurm_acct_db","username":"slurm","password":"..."}
```
