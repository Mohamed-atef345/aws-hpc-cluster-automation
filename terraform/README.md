# Terraform infrastructure

This directory is the single root module for the disposable AWS HPC environment.
It uses the existing encrypted S3 backend declared in `providers.tf` and
contains reusable child modules under `modules/`.

## Intended implementation order

1. `network`
2. `security`
3. `storage`
4. `ec2_node`

Persistent IAM, instance profiles, GitHub OIDC permissions, and empty Secrets
Manager containers are managed by the separate `identity/` root.

The persistent identity root is an administrator bootstrap stack, not part of
the normal deployment workflow. CI assumes the role created by that stack and
applies or destroys only this disposable root.

Run Terraform from this directory:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init -reconfigure
terraform fmt -recursive
terraform validate
terraform plan
```

The backend bucket is persistent and is not managed by this disposable root
module. Destroying this root must remove the lab resources without deleting
the remote state bucket.

Both Terraform roots currently pass `terraform fmt -check -recursive` and
`terraform validate`. The deployment role has the transfer-bucket and SSM
permissions required to apply this root and run Ansible.

For CI, initialize with `terraform init -backend=false` and run formatting and
validation without AWS credentials. For the protected deployment job, assume
the identity stack's `github_terraform_role_arn` through OIDC and use the real
backend.

Pass these non-secret environment values to the disposable root:

```text
TF_VAR_aws_region
TF_VAR_project_name
TF_VAR_owner
TF_VAR_availability_zone
TF_VAR_ami_id
TF_VAR_compute_count
```

The remaining instance types, CIDRs, volume sizes, and storage settings may use
their committed defaults or be exposed as additional `TF_VAR_*` environment
variables when an environment needs overrides. `TF_VAR_project_name` must match
the persistent identity root's `name_prefix` so tags, IAM conditions, and the
deterministic transfer-bucket name remain aligned.
