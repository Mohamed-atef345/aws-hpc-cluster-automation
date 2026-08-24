# HPCSlurmFreeIPA

An automated AWS HPC lab that combines FreeIPA centralized identity with Slurm
workload scheduling. Terraform provisions the infrastructure, Ansible will
configure the cluster services, and GitHub Actions will provide validation and
controlled deployment through AWS OIDC.

> **Current milestone:** Terraform infrastructure is implemented and valid.
> The persistent identity stack rename must be reviewed and applied before the
> first cluster deployment. Ansible is the next development phase.

## Overview

This project demonstrates the infrastructure and Linux systems engineering
needed to build a small but complete HPC environment:

- Private AWS networking with controlled outbound access
- Centralized users, groups, Kerberos, LDAP, DNS, and SSSD through FreeIPA
- Slurm controller, compute execution, login access, and job accounting
- Shared POSIX storage through Amazon EFS
- Per-compute-node EBS scratch storage
- Tag-driven Ansible dynamic inventory
- Private administration through AWS Systems Manager
- GitHub Actions authentication to AWS without long-lived access keys

The lab is intentionally compact—one FreeIPA server, one controller, one login
node, and two compute nodes—so it can be deployed temporarily, demonstrated,
and destroyed to control cost.

## Project status

Status values: **Complete**, **In progress**, **Planned**, and **Deferred**.

| Phase                | Status      | Completion requirement                                             | Evidence                        |
| -------------------- | ----------- | ------------------------------------------------------------------ | ------------------------------- |
| Architecture         | Complete    | Components, trust boundaries, network, and service flow documented | [Architecture](ARCHITECTURE.md) |
| Terraform backend    | Complete    | Separate S3 state and locking for persistent and disposable roots  | `terraform validate`            |
| IAM and GitHub OIDC  | In progress | Apply the `HPCSlurmFreeIPA` rename and verify role assumption      | Identity plan reviewed          |
| Network              | Complete    | VPC, subnets, NAT, IGW, routes, and outputs implemented            | Main plan: 50 resources         |
| Security groups      | Complete    | FreeIPA, Slurm, EFS, and `srun` rules implemented                  | Terraform validation            |
| Storage              | Complete    | EFS access points and compute scratch EBS implemented              | Terraform validation            |
| EC2 nodes            | Complete    | Five private nodes, IMDSv2, encryption, SSM bootstrap              | Terraform validation            |
| Secrets metadata     | Complete    | Empty secret containers and least-privilege IAM access             | No values in state              |
| AWS deployment       | Planned     | Apply infrastructure and confirm five SSM-managed nodes            | Add deployment evidence         |
| Ansible base         | Planned     | Dynamic inventory, hostnames, packages, time, and DNS              | Add play recap                  |
| FreeIPA              | Planned     | Server installed, clients enrolled, user login validated           | Add identity evidence           |
| Shared storage       | Planned     | EFS and scratch mounts configured idempotently                     | Add mount evidence              |
| Slurm and accounting | Planned     | MUNGE, MariaDB, SlurmDBD, controller, login, and compute working   | Add Slurm evidence              |
| End-to-end demo      | Planned     | FreeIPA user submits and tracks a multi-node job                   | Add job output                  |
| GitHub Actions       | Planned     | CI, reviewed deployment, validation, and teardown workflows        | Add workflow link               |
| CloudWatch           | Deferred    | Not part of the current scope                                      | —                               |

## Architecture

```mermaid
flowchart TB
    Engineer[Engineer or GitHub Actions] -->|Terraform / AWS OIDC| AWS[AWS APIs]
    Engineer -->|Session Manager| SSM[AWS Systems Manager]

    subgraph VPC[HPCSlurmFreeIPA VPC - 10.20.0.0/16]
        subgraph Public[Public subnet - 10.20.0.0/24]
            IGW[Internet gateway]
            NAT[NAT gateway]
        end

        subgraph Private[Private subnet - 10.20.10.0/24]
            IPA[ipa01<br/>FreeIPA<br/>10.20.10.10]
            Controller[ctl01<br/>slurmctld + slurmdbd + MariaDB<br/>10.20.10.20]
            Login[login01<br/>Login and job submission<br/>10.20.10.30]
            Compute1[compute01<br/>slurmd + scratch EBS<br/>10.20.10.100]
            Compute2[compute02<br/>slurmd + scratch EBS<br/>10.20.10.101]
            EFS[(One Zone EFS<br/>/home and /shared)]
        end

        Private --> NAT --> IGW
        Login -->|Kerberos / LDAP / DNS| IPA
        Controller -->|Identity lookup| IPA
        Compute1 -->|Identity lookup| IPA
        Compute2 -->|Identity lookup| IPA
        Login -->|Slurm client requests| Controller
        Controller -->|Workload control| Compute1
        Controller -->|Workload control| Compute2
        IPA --> EFS
        Controller --> EFS
        Login --> EFS
        Compute1 --> EFS
        Compute2 --> EFS
    end

    SSM --> IPA
    SSM --> Controller
    SSM --> Login
    SSM --> Compute1
    SSM --> Compute2
```

## Component inventory

### Nodes

| Node        | Role       | Private IP     | Default size | Planned services                        |
| ----------- | ---------- | -------------- | ------------ | --------------------------------------- |
| `ipa01`     | FreeIPA    | `10.20.10.10`  | `t3.medium`  | FreeIPA, Kerberos, LDAP, DNS, CA        |
| `ctl01`     | Controller | `10.20.10.20`  | `t3.medium`  | `slurmctld`, `slurmdbd`, MariaDB, MUNGE |
| `login01`   | Login      | `10.20.10.30`  | `t3.small`   | SSSD, MUNGE, Slurm client tools         |
| `compute01` | Compute    | `10.20.10.100` | `t3.small`   | SSSD, MUNGE, `slurmd`                   |
| `compute02` | Compute    | `10.20.10.101` | `t3.small`   | SSSD, MUNGE, `slurmd`                   |

All nodes use the pinned Rocky Linux 9 AMI
`ami-07f1ef003bc5de2b1` in `us-east-1`, owned by Rocky Linux account
`792107900819`.

### Storage

| Storage                    | Scope         | Intended mount | Purpose                                            |
| -------------------------- | ------------- | -------------- | -------------------------------------------------- |
| Encrypted EFS access point | Cluster       | `/home`        | Shared FreeIPA user home directories               |
| Encrypted EFS access point | Cluster       | `/shared`      | Shared applications, data, scripts, and job output |
| Encrypted gp3 root EBS     | Every node    | `/`            | Operating system and installed services            |
| Encrypted gp3 scratch EBS  | Compute nodes | `/scratch`     | Node-local temporary job data                      |

Terraform attaches compute scratch volumes as `/dev/sdf`. Ansible must locate
the corresponding NVMe device by EBS volume identity rather than assuming the
guest device name remains `/dev/sdf`.

### Network and service ports

| Destination | Source          | Ports           | Purpose                           |
| ----------- | --------------- | --------------- | --------------------------------- |
| FreeIPA     | Cluster clients | TCP/UDP 53      | DNS                               |
| FreeIPA     | Cluster clients | TCP 80, 443     | Enrollment, API, web interface    |
| FreeIPA     | Cluster clients | TCP/UDP 88      | Kerberos authentication           |
| FreeIPA     | Cluster clients | TCP 389, 636    | LDAP and LDAPS                    |
| FreeIPA     | Cluster clients | TCP/UDP 464     | Kerberos password service         |
| Controller  | Cluster clients | TCP 6817        | Slurm controller                  |
| Compute     | Controller      | TCP 6818        | Slurm daemon control              |
| Controller  | Cluster clients | TCP 6819        | SlurmDBD accounting               |
| Login       | Compute         | TCP 60001-60010 | Interactive `srun` return traffic |
| EFS         | Cluster clients | TCP 2049        | NFSv4.1                           |

No instance receives a public IP address or internet-facing SSH rule.
Administration uses AWS Systems Manager.

## Identity and scheduling flow

FreeIPA and Slurm solve different parts of authentication and authorization:

1. A user authenticates on `login01` through PAM and SSSD backed by FreeIPA.
2. SSSD resolves the user's POSIX UID, GID, groups, and home directory.
3. The user runs `sbatch`, `srun`, `squeue`, or `sacct` on the login node.
4. MUNGE signs Slurm credentials exchanged between Slurm components.
5. `slurmctld` allocates one or more compute nodes.
6. `slurmd` resolves the same user identity and launches the process under the
   correct UID and GID.
7. EFS presents the same home directory and shared data on all required nodes.
8. SlurmDBD records the job in MariaDB for later inspection with `sacct`.

FreeIPA does not replace MUNGE. MUNGE authenticates Slurm messages; FreeIPA
provides the human user's centralized identity.

## Repository structure

```text
.
├── README.md
├── ARCHITECTURE.md
├── terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── locals.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   ├── identity/
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── locals.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── modules/
│       ├── network/
│       ├── security/
│       ├── storage/
│       ├── ec2_node/
│       ├── iam/
│       └── secrets/
└── ansible/                    # Planned next phase
```

Documentation ownership:

- Architecture decisions: `ARCHITECTURE.md`
- Terraform usage: `terraform/README.md`
- Persistent identity usage: `terraform/identity/README.md`
- Future Ansible usage: `ansible/README.md`

## Terraform design

### State boundaries

| Root                 | State key                                          | Lifecycle  | Main resources                                  |
| -------------------- | -------------------------------------------------- | ---------- | ----------------------------------------------- |
| `terraform/identity` | `slurm-cluster-freeipa/identity/terraform.tfstate` | Persistent | IAM, profiles, OIDC role, secret containers     |
| `terraform`          | `slurm-cluster-freeipa/dev/terraform.tfstate`      | Disposable | Network, security groups, EFS, EC2, scratch EBS |

The backend retains its existing lowercase path to avoid an unnecessary state
migration. There is no Terraform `environment` variable or `Environment` AWS
tag.

### Tag-driven discovery

Common tags:

```text
Project   = HPCSlurmFreeIPA
Owner     = mohamed-atef
ManagedBy = terraform
```

EC2 discovery tags:

```text
NodeName       = ipa01 | ctl01 | login01 | compute01 | compute02
Role           = freeipa | controller | login | compute
AnsibleManaged = true
```

These tags will let the Ansible AWS inventory plugin discover running nodes
and build groups from `Role` without a static inventory file.

### Secrets

Terraform creates empty metadata containers only:

```text
HPCSlurmFreeIPA/freeipa/credentials
HPCSlurmFreeIPA/slurm/munge
HPCSlurmFreeIPA/slurm/database
```

Expected JSON schemas:

```json
{"admin_password": "...", "directory_manager_password": "..."}
```

```json
{"munge_key_base64": "..."}
```

```json
{"database_name": "slurm_acct_db", "username": "slurm", "password": "..."}
```

Values are populated outside Terraform so they never enter Terraform state.
Node roles receive only the secrets required by that role. Sensitive Ansible
tasks must use `no_log: true`.

Secret deletion has no recovery window. Removing a container from Terraform
causes immediate, unrecoverable deletion.

## Deployment

### Prerequisites

- Terraform `>= 1.10.0, < 2.0.0`
- AWS provider `~> 6.61`
- AWS CLI credentials authorized to manage the identity root
- Existing encrypted S3 backend bucket
- Existing GitHub Actions OIDC provider in the AWS account
- Access to `us-east-1` and sufficient service quotas

### 1. Apply persistent identity

```bash
cp terraform/identity/terraform.tfvars.example terraform/identity/terraform.tfvars
terraform -chdir=terraform/identity init -reconfigure
terraform -chdir=terraform/identity fmt -recursive
terraform -chdir=terraform/identity validate
terraform -chdir=terraform/identity plan -out=identity.tfplan
terraform -chdir=terraform/identity apply identity.tfplan
```

The current identity state uses the former lowercase prefix. Review the plan
carefully: changing to `HPCSlurmFreeIPA` replaces existing IAM names and secret
containers. Copy any required secret values before applying.

### 2. Populate secret values

Use the AWS Secrets Manager console and the documented JSON schemas. Never put
secret values in Terraform variables, `.tfvars`, GitHub, or committed files.

### 3. Apply disposable infrastructure

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
terraform -chdir=terraform init -reconfigure
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=cluster.tfplan
terraform -chdir=terraform apply cluster.tfplan
```

### 4. Confirm private-node management

```bash
aws ssm describe-instance-information \
  --region us-east-1 \
  --query 'InstanceInformationList[*].[InstanceId,PingStatus,PlatformName]' \
  --output table
```

Do not start application configuration until all expected instances report
`Online`.

## Ansible implementation plan

```text
ansible/
├── README.md
├── ansible.cfg
├── requirements.yml
├── inventory/
│   └── aws_ec2.yml
├── group_vars/
│   ├── all.yml
│   ├── freeipa.yml
│   ├── controller.yml
│   ├── login.yml
│   └── compute.yml
├── playbooks/
│   ├── site.yml
│   └── validate.yml
└── roles/
    ├── common/
    ├── storage_client/
    ├── freeipa_server/
    ├── freeipa_client/
    ├── munge/
    ├── mariadb/
    ├── slurmdbd/
    ├── slurm_controller/
    ├── slurm_login/
    └── slurm_compute/
```

Implementation order:

1. Dynamic AWS inventory and role-based groups
2. SSM connection and base operating-system configuration
3. Stable hostnames, DNS, and time synchronization
4. FreeIPA server installation
5. FreeIPA client enrollment and SSSD validation
6. EFS client mounts and compute scratch mounts
7. Shared MUNGE authentication
8. MariaDB and SlurmDBD
9. Slurm controller, login client, and compute daemons
10. End-to-end validation playbook

When each role is completed, update the project-status table and add its
validation result to the next section.

## Validation and demonstration evidence

Replace each pending result with sanitized evidence when that milestone passes.

| Test                 | Expected result                            | Current result | Evidence              |
| -------------------- | ------------------------------------------ | -------------- | --------------------- |
| Terraform formatting | Both roots pass recursive formatting       | Passed         | Add CI link later     |
| Terraform validation | Both roots are valid                       | Passed         | Local validation      |
| Infrastructure plan  | 50 disposable resources proposed           | Passed         | Add plan summary      |
| SSM registration     | Five nodes report `Online`                 | Pending        | Add screenshot/output |
| Dynamic inventory    | Five hosts grouped by `Role`               | Pending        | Add inventory graph   |
| FreeIPA health       | IPA services healthy                       | Pending        | Add `ipactl status`   |
| Kerberos             | Test user receives a ticket                | Pending        | Add `klist` output    |
| Central identity     | Same UID/GID on login and compute          | Pending        | Add `id` output       |
| EFS mounts           | `/home` and `/shared` mounted              | Pending        | Add `findmnt` output  |
| Compute scratch      | `/scratch` mounted on both compute nodes   | Pending        | Add `findmnt` output  |
| MUNGE                | Credential validates across nodes          | Pending        | Add MUNGE output      |
| Slurm nodes          | Both compute nodes are `IDLE`              | Pending        | Add `sinfo` output    |
| Batch job            | FreeIPA user job completes                 | Pending        | Add `sbatch` output   |
| Multi-node execution | `srun hostname` reaches both compute nodes | Pending        | Add job output        |
| Accounting           | Completed job appears in `sacct`           | Pending        | Add accounting output |

### Final demonstration job

```bash
#!/bin/bash
#SBATCH --job-name=cluster-test
#SBATCH --nodes=2
#SBATCH --output=/shared/cluster-test-%j.out

id
hostname
date
srun hostname
```

## CI/CD roadmap

| Workflow      | Trigger               | Responsibility                                   | Status  |
| ------------- | --------------------- | ------------------------------------------------ | ------- |
| `ci.yml`      | Pull request and push | Terraform checks, Ansible syntax and lint        | Planned |
| `deploy.yml`  | Manual approval       | OIDC login, apply, SSM wait, Ansible, validation | Planned |
| `destroy.yml` | Manual approval       | Destroy disposable root only                     | Planned |

The deployment role still needs narrowly scoped SSM control-plane permissions
before a GitHub-hosted workflow can execute remote configuration.

## Teardown and cost control

```bash
terraform -chdir=terraform plan -destroy -out=destroy.tfplan
terraform -chdir=terraform apply destroy.tfplan
```

This removes the VPC, NAT gateway, EC2 instances, EFS, root volumes, and
compute scratch volumes. The persistent identity root and backend remain.

Primary cost drivers are NAT gateway uptime, EC2 running hours, EBS storage,
EFS data, and active Secrets Manager containers. Stopping EC2 does not stop the
other charges; destroy the disposable root when the lab is not needed.

## Security decisions

- Private-only EC2 instances and no internet-facing SSH
- Systems Manager administration and IMDSv2 enforcement
- Encrypted EC2 root, scratch EBS, and EFS storage
- Role-specific instance profiles
- Exact GitHub OIDC subject with no wildcard
- Least-privilege secret access by node role
- No secret values in Terraform state or Git
- Immediate secret deletion selected for this short-lived lab

## Known limitations

- Single Availability Zone and no service high availability
- One FreeIPA server and one Slurm controller
- MariaDB and SlurmDBD colocated with the controller
- EFS rather than an HPC parallel filesystem
- Fixed compute capacity rather than elastic nodes
- NAT gateway required for outbound package installation
- Account-specific Terraform backend configuration
- Manual secret-value population
- Ansible and CI/CD not implemented yet
- CloudWatch intentionally deferred

## Completion checklist

- [x] Architecture documented
- [x] Persistent and disposable Terraform roots created
- [x] Terraform modules implemented and validated
- [ ] Apply the uppercase identity-resource migration
- [ ] Populate secret values securely
- [ ] Deploy disposable infrastructure and verify SSM
- [ ] Implement Ansible dynamic inventory and common role
- [ ] Implement FreeIPA server and client enrollment
- [ ] Implement EFS and compute scratch configuration
- [ ] Implement MUNGE, MariaDB, SlurmDBD, and Slurm
- [ ] Pass the FreeIPA-user multi-node job demonstration
- [ ] Add CI, deploy, and destroy workflows
- [ ] Add sanitized screenshots and command evidence
- [ ] Finalize the CV project entry

## Portfolio results

Complete this section only after the acceptance tests pass.

### Demonstrated outcomes

<!-- Add 3-5 measurable outcomes after validation. -->

### Screenshots and evidence

<!-- Add sanitized Terraform, Ansible, FreeIPA, and Slurm evidence. -->

### CV-ready project entry

<!-- Replace this placeholder after completion:

HPCSlurmFreeIPA — Automated AWS HPC Cluster
- Built a private AWS HPC lab integrating FreeIPA centralized authentication
  with Slurm scheduling and accounting across controller, login, and compute nodes.
- Provisioned modular AWS infrastructure with Terraform and automated Linux and
  service configuration through tag-driven Ansible inventory.
- Implemented shared EFS home directories, compute scratch storage, SSM-based
  administration, least-privilege IAM, and GitHub Actions OIDC deployment.
-->

## Maintaining this README

After finishing a project phase:

1. Update its row in **Project status**.
2. Add the exact result in **Validation and demonstration evidence**.
3. Mark the corresponding item in **Completion checklist**.
4. Add only sanitized output—never credentials, tokens, state contents, or
   private account data.
5. Move detailed operational instructions into the relevant component README.

This keeps the opening sections concise for portfolio reviewers while the rest
of the document provides technical evidence for engineering readers.
