# Terraform infrastructure

This directory is the single root module for the disposable AWS HPC environment.
It uses the existing encrypted S3 backend declared in `providers.tf` and
contains reusable child modules under `modules/`.

## Intended implementation order

1. `network`
2. `security`
3. `iam`
4. `storage`
5. `ec2_node`
6. `secrets`
7. `observability`

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
