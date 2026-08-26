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

The roles pass local syntax validation. Runtime validation against the deployed
AWS environment is still pending.

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

The role intentionally creates users without passwords. An administrator must
set each initial password after deployment:

```bash
kinit admin
ipa passwd hpcuser
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

### Storage validation

`playbooks/validate.yml` performs read-only scratch checks. It confirms that
`/scratch` is actively mounted as XFS, has a persistent UUID-based fstab entry,
and is owned by `root:root` with mode `1777`:

```bash
ansible-playbook \
  -e "ansible_aws_ssm_bucket_name=${ANSIBLE_TRANSFER_BUCKET}" \
  playbooks/validate.yml
```

## Secrets prerequisite

Terraform creates the secret container but does not place values in it. Before
running the playbook, populate `HPCSlurmFreeIPA/freeipa/credentials` with:

```json
{
  "admin_password": "REPLACE_ME",
  "directory_manager_password": "REPLACE_ME"
}
```
