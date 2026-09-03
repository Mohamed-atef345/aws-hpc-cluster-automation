# Ansible configuration

This directory contains the tag-driven configuration layer for the private AWS
HPC cluster. The dynamic inventory connects to EC2 instances through AWS
Systems Manager rather than SSH.

## Current status

Implemented and syntax-valid:

- Dynamic EC2 inventory and role-based groups
- Common Rocky Linux 9 configuration
- FreeIPA server with integrated DNS
- FreeIPA client enrollment
- FreeIPA users, groups, and centralized sudo policy
- EFS clients for shared `/home` and `/shared` storage
- Identity-safe compute scratch storage mounted at `/scratch`
- Shared MUNGE authentication for all Slurm nodes
- Controller-local MariaDB storage for Slurm accounting
- Shared Slurm packages and inventory-derived configuration
- SlurmDBD and `slurmctld` on the controller
- `slurmd` plus per-job scratch prolog and epilog on compute nodes
- Login-node Slurm client and example multi-node job

The roles pass local syntax validation, the shell templates pass `bash -n`, and
the Slurm configuration templates render with representative inventory data.
Runtime validation against the deployed AWS environment is still pending.

## Remaining deployment gate

The variable-scope, AWS CLI installation, and FreeIPA idempotency findings from
the September 2026 static audit are corrected. `playbooks/validate.yml` still
needs Slurm service, node-registration, job, output, and `sacct` coverage before
it can serve as the complete deployment acceptance gate.

## Inventory and connection

`inventory/cluster.aws_ec2.yml` discovers running instances with these tags:

```text
Project        = HPCSlurmFreeIPA
ManagedBy      = terraform
AnsibleManaged = true
Role           = freeipa | controller | login | compute
NodeName       = ipa01 | ctl01 | login01 | compute01 | compute02
```

The `Role` tag creates the primary groups. The inventory also creates:

- `freeipa_clients`: controller, login, and compute nodes
- `slurm_nodes`: controller, login, and compute nodes

Connections use `amazon.aws.aws_ssm`. Terraform creates a dedicated private S3
transfer bucket and exports its name as `ansible_transfer_bucket_name`. Pass
that value to the connection plugin at runtime:

```bash
ANSIBLE_TRANSFER_BUCKET="$(
  terraform -chdir=../terraform output -raw ansible_transfer_bucket_name
)"
EFS_FILE_SYSTEM_ID="$(
  terraform -chdir=../terraform output -raw efs_file_system_id
)"
EFS_HOME_ACCESS_POINT_ID="$(
  terraform -chdir=../terraform output -raw efs_home_access_point_id
)"
EFS_SHARED_ACCESS_POINT_ID="$(
  terraform -chdir=../terraform output -raw efs_shared_access_point_id
)"

ansible-playbook \
  -e "ansible_aws_ssm_bucket_name=${ANSIBLE_TRANSFER_BUCKET}" \
  -e "efs_file_system_id=${EFS_FILE_SYSTEM_ID}" \
  -e "efs_home_access_point_id=${EFS_HOME_ACCESS_POINT_ID}" \
  -e "efs_shared_access_point_id=${EFS_SHARED_ACCESS_POINT_ID}" \
  playbooks/site.yml
```

GitHub Actions should obtain the same Terraform output after applying the
infrastructure and pass it through the same extra variable. The bucket name is
not a secret.

The pipeline must derive, rather than manually store, these Ansible inputs:

| Ansible extra variable                | Terraform output                    |
| ------------------------------------- | ----------------------------------- |
| `ansible_aws_ssm_bucket_name`         | `ansible_transfer_bucket_name`      |
| `efs_file_system_id`                  | `efs_file_system_id`                |
| `efs_home_access_point_id`            | `efs_home_access_point_id`          |
| `efs_shared_access_point_id`          | `efs_shared_access_point_id`        |

The OIDC-provided AWS environment variables are reused automatically by the
dynamic inventory and SSM connection plugin. The only human credential passed
to Ansible is the protected `HPCUSER_INITIAL_PASSWORD` environment secret. Do
not pass service credentials, the MUNGE key, or long-lived AWS keys to Ansible.

## Installation and validation

From the repository root:

```bash
python3 -m pip install -r ansible/requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml

cd ansible
ansible-inventory --graph
ansible-playbook --syntax-check playbooks/site.yml
ansible-playbook --syntax-check playbooks/validate.yml
```

An empty-inventory warning during a local syntax check is expected when no AWS
instances are currently running.

In CI, avoid querying AWS by replacing the last two commands with:

```bash
ANSIBLE_INVENTORY_ENABLED=host_list,auto,yaml \
  ansible-playbook -i localhost, --syntax-check playbooks/site.yml
ANSIBLE_INVENTORY_ENABLED=host_list,auto,yaml \
  ansible-playbook -i localhost, --syntax-check playbooks/validate.yml
```

## Implemented role flow

### `common`

- Verifies Rocky Linux 9 and required EC2 inventory metadata.
- Installs shared utilities, AWS CLI v2, DNS, NFS, and SELinux tooling.
- Configures Chrony with Amazon Time Sync Service at `169.254.169.123`.
- Sets each hostname to `<NodeName>.cluster.internal`.
- Creates temporary managed `/etc/hosts` entries for initial bootstrap.

### `freeipa_server`

- Installs `ipa-server`, integrated DNS, and `firewalld`.
- Opens the `freeipa-4` and DNS firewalld services.
- Verifies the credentials secret contains `admin_password` and
  `directory_manager_password`.
- Retrieves those values locally through the FreeIPA EC2 instance role.
- Installs `ipa01.cluster.internal` non-interactively for the
  `CLUSTER.INTERNAL` realm.
- Forwards external DNS to the VPC resolver at `10.20.0.2`.
- Validates services, DNS records, forwarding, Kerberos authentication, and the
  FreeIPA API.

The installer uses `/etc/ipa/default.conf` as its idempotency marker. Sensitive
installation and authentication tasks use `no_log: true`.

### `freeipa_identity`

The role creates these POSIX groups and demonstration users:

| User       | Groups                    | Home directory   |
| ---------- | ------------------------- | ---------------- |
| `hpcuser`  | `hpc_users`               | `/home/hpcuser`  |
| `hpcadmin` | `hpc_users`, `hpc_admins` | `/home/hpcadmin` |

The `hpc-admins-all` FreeIPA sudo rule grants members of `hpc_admins` full sudo
access on all enrolled hosts. Membership in `hpc_users` does not grant sudo.

Administrator operations use a unique temporary Kerberos credential cache. An
Ansible `always` block destroys the ticket and removes its cache directory after
both successful and failed identity-management runs.

The role reads `HPCUSER_INITIAL_PASSWORD` from the Ansible controller process
and assigns it only when `hpcuser` is first created. The password never appears
in task output because the validation and password tasks use `no_log: true`.
Existing users are not modified during later idempotent runs.

The example `hpcadmin` account is intentionally created without a password. If
interactive authentication is required for that account, an administrator can
set it after deployment:

```bash
kinit admin
ipa passwd hpcadmin
```

The administrator-set password is temporary by default, and the user is asked
to replace it during first authentication.

### `freeipa_client`

- Configures NetworkManager to use FreeIPA DNS with the VPC resolver as a
  fallback.
- Validates the FreeIPA A, LDAP SRV, Kerberos SRV, and public DNS results.
- Installs the IPA client, SSSD tools, and automatic home-directory support.
- Delegates one-time enrollment-password creation to `ipa01`, keeping the
  FreeIPA administrator secret away from client instance roles.
- Enrolls controller, login, and compute nodes non-interactively.
- Confirms the host keytab exists and the SSSD domain is online.

### `storage_client`

- Verifies the EFS filesystem and access-point IDs supplied from Terraform.
- Installs the EFS mount helper.
- Mounts the encrypted access points persistently at `/home` and `/shared`
  using TLS.
- Verifies both active mounts.
- Configures `/shared` as `root:hpc_users` with mode `2775` so new content
  inherits the HPC users group.

### `scratch_storage`

- Runs only on compute nodes and selects Terraform's `/dev/sdf` attachment from
  EC2 inventory metadata.
- Matches the attachment's EBS volume ID to the exact NVMe serial instead of
  assuming a guest device name.
- Creates XFS only when the disk has no existing signatures and refuses disks
  containing any unexpected filesystem, RAID, or partition signature.
- Mounts the filesystem persistently by UUID at `/scratch` with `noatime`.
- Configures `/scratch` as `root:root` with mode `1777`.

The scratch role is tagged for an isolated first run and idempotency check:

```bash
ansible-playbook \
  -e "ansible_aws_ssm_bucket_name=${ANSIBLE_TRANSFER_BUCKET}" \
  playbooks/site.yml \
  --limit compute \
  --tags scratch_storage
```

Run the same command twice. The second run should report `changed=0` for both
compute nodes.

### `munge`

- Installs MUNGE on the controller, login, and compute nodes.
- Retrieves the shared key directly from AWS Secrets Manager through each
  node's instance role.
- Installs the key atomically with `munge:munge` ownership and mode `0600`.
- Restarts MUNGE only when the key changes and tests local credential handling.

### `mariadb`

- Installs MariaDB on the controller and restricts it to loopback connections.
- Applies Slurm-oriented InnoDB settings through a dedicated configuration
  file.
- Retrieves the database name, user, and password through the controller's
  instance role without logging them.
- Creates the case-insensitive accounting database and a local user whose
  privileges are limited to that database.
- Tests the same database connection that SlurmDBD will use.
- Leaves TCP port `3306` private to the controller; SlurmDBD will expose its
  separate accounting interface on port `6819`.

### `slurm_common`

- Installs the pinned Slurm base package from EPEL 9 with CRB enabled for
  dependencies.
- Creates the shared configuration, log, daemon-spool, and controller-state
  directories with the required service ownership.
- Renders `/etc/slurm/slurm.conf` on every Slurm node.
- Derives each compute node's name, private address, CPU count, and usable
  memory from dynamic inventory and gathered facts.
- Configures MUNGE authentication, consumable CPU and memory scheduling,
  SlurmDBD accounting, and the `debug` partition.

### `slurmdbd`

- Installs the version-matched SlurmDBD package on the controller.
- Renders a protected `root:slurm` accounting configuration from the MariaDB
  facts produced earlier in the controller play.
- Starts or restarts SlurmDBD only as required by configuration changes.
- Registers `hpc-cluster` with `sacctmgr` when it does not already exist.

### `slurm_controller`

- Installs the version-matched `slurmctld` package.
- Enables and starts the controller after MariaDB and SlurmDBD are ready.
- Restarts the service when the shared Slurm configuration changed.

### `slurm_compute`

- Installs the version-matched `slurmd` package on every compute node.
- Installs root-owned executable prolog and epilog scripts.
- Creates `/scratch/$SLURM_JOB_ID` with the submitting job's UID and GID and
  mode `0700`, then removes only that validated numeric job directory at job
  completion.
- Starts or restarts `slurmd` after its configuration and scripts are ready.

### `slurm_login`

- Creates `/shared/examples` as `root:hpc_users` with setgid mode `2775`.
- Installs `hostname.sbatch`, which requests up to two compute nodes, launches
  one task per node, and writes its result under `/shared`.
- Runs after the compute role so the example is installed only after the
  execution partition has been configured.

### Validation

`playbooks/validate.yml` currently performs read-only checks for scratch
storage, cross-node MUNGE authentication, and MariaDB accounting-database
access:

```bash
ansible-playbook \
  -e "ansible_aws_ssm_bucket_name=${ANSIBLE_TRANSFER_BUCKET}" \
  playbooks/validate.yml
```

Before using it as the deployment acceptance gate, add checks for active
SlurmDBD, `slurmctld`, and `slurmd` services; registered compute nodes; a
completed `/shared/examples/hostname.sbatch` submission as a FreeIPA user; the
shared output file; and the corresponding completed `sacct` record.

## Secrets prerequisites

Terraform creates the secret containers but does not place values in them.
Before running the playbook, populate each container with its matching JSON.

`HPCSlurmFreeIPA/freeipa/credentials`:

```json
{
  "admin_password": "REPLACE_ME",
  "directory_manager_password": "REPLACE_ME"
}
```

`HPCSlurmFreeIPA/slurm/munge`:

```json
{
  "munge_key_base64": "REPLACE_ME"
}
```

`HPCSlurmFreeIPA/slurm/database`:

```json
{
  "database_name": "slurm_acct_db",
  "username": "slurm",
  "password": "REPLACE_ME"
}
```
