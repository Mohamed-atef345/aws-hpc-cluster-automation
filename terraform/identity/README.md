# Persistent project identity

This root module creates the project's persistent EC2 roles, instance profiles,
Secrets Manager containers, GitHub Actions deployment role, and associated
least-privilege policies. It references the GitHub OIDC provider that already
exists in the AWS account. Secret values are populated outside Terraform so
they are never stored in Terraform state.

This stack has a separate S3 state key and must not be destroyed when the
disposable HPC lab is torn down.

Apply this bootstrap stack with an administrator identity before creating the
GitHub Actions workflows. The workflow cannot create the role that it must
already assume, and the deployment role is intentionally not granted permission
to modify this persistent identity stack. Normal CI/CD applies and destroys only
the disposable `terraform/` root.

Treat replacement of an existing IAM role or Secrets Manager container as a
failed plan review. In particular, `name_prefix` is case-sensitive and is part
of those physical names. Reconcile any difference between the configured value
and the existing state before applying; do not use a deployment workflow to
accept those replacements.

Before planning, copy `terraform.tfvars.example` to `terraform.tfvars`. For this
repository, the protected `dev` environment uses this exact subject:

```hcl
github_oidc_subject = "repo:Mohamed-atef345@148637608/aws-hpc-cluster-automation@1344863857:environment:dev"
```

```bash
terraform init -reconfigure
terraform fmt -recursive
terraform validate
terraform plan
```

## Deployment-role readiness

The role contains the permissions required by the deployment workflow:

- The transfer-bucket policy is restricted to the deterministic bucket derived
  from `name_prefix`, the AWS account ID, and `aws_region`. It covers the bucket
  controls managed by Terraform and the temporary objects used by Ansible.
- SSM session startup is restricted to EC2 instances tagged with the matching
  `Project` value and `ManagedBy=terraform`.
- Status inspection, the default Session Manager document, session data
  channels, and session termination are granted separately.

Keep backend-state permissions separate from transfer-bucket permissions; the
current state policy is deliberately limited to the two Terraform state keys
and their lock object.

After applying this root with administrator credentials, save
`github_terraform_role_arn` as the non-secret GitHub environment variable
`AWS_DEPLOY_ROLE_ARN`. Set the workflow job's environment to the same protected
environment encoded in `github_oidc_subject`; otherwise the OIDC `sub` claim
will not match and role assumption will be denied.

The root also creates a separate `github_secrets_bootstrap_role_arn`. Save it as
the non-secret GitHub environment variable `AWS_SECRETS_BOOTSTRAP_ROLE_ARN` and
use it only for the protected secret-initialization step in `deploy.yml`. It can
list versions and add a value to the three project secret containers, but it
cannot read secret values, create or delete containers, or deploy infrastructure.

The current role ARN can be read without copying it from the AWS console:

```bash
terraform -chdir=terraform/identity output -raw github_terraform_role_arn
terraform -chdir=terraform/identity output -raw github_secrets_bootstrap_role_arn
```

Use it from GitHub Actions with short-lived OIDC credentials:

```yaml
permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - uses: actions/checkout@v6
      - name: Authenticate to AWS with OIDC
        uses: aws-actions/configure-aws-credentials@v6.2.3
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - name: Verify the assumed identity
        run: aws sts get-caller-identity
```

`environment: dev` is required here, not just useful for approvals: it makes
GitHub issue the `...:environment:dev` subject required by the IAM trust policy.
This repository was created after GitHub's July 15, 2026 immutable-subject
cutoff, so the owner and repository IDs in the `repo:` segment are also
required.

## Secret values

Terraform creates these empty secret containers only:

- `HPCSlurmFreeIPA/freeipa/credentials`
- `HPCSlurmFreeIPA/slurm/munge`
- `HPCSlurmFreeIPA/slurm/database`

The protected deployment workflow generates their initial values and writes
them directly through the dedicated bootstrap role. It skips any container that
already has an `AWSCURRENT` version. Do not add
`aws_secretsmanager_secret_version` resources or commit secret JSON files,
because doing so would place credentials in Terraform state or Git history.

The separate `HPCUSER_INITIAL_PASSWORD` GitHub environment secret is a human
login credential. It is passed only to the Ansible identity role and is not
stored in these service-secret containers.

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

## Destroy the persistent identity stack

Destroy this root only when permanently removing the whole project, never as
part of routine lab teardown. Run it with an administrator identity; the GitHub
deployment role intentionally cannot delete itself or the other persistent IAM
resources.

The three Secrets Manager containers use `recovery_window_in_days = 0`, so this
destroy permanently deletes their current values immediately. Back up or rotate
anything still needed before continuing, and destroy the disposable
`terraform/` root first so no instance profile remains attached to an EC2
instance.

```bash
terraform -chdir=terraform/identity init -reconfigure
terraform -chdir=terraform/identity plan -destroy -out=identity-destroy.tfplan
terraform -chdir=terraform/identity show identity-destroy.tfplan
terraform -chdir=terraform/identity apply identity-destroy.tfplan
```

This removes the project IAM roles, instance profiles, inline policies, and
Secrets Manager containers. It does not remove the account-level GitHub OIDC
provider or the S3 Terraform backend, because this root only references them.
