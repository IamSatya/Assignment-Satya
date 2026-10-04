# DevOps Assignment Solutions

This repository contains my solutions for the 5 DevOps assignment tasks, covering EC2 provisioning with Terraform, remote state locking with S3 and DynamoDB, cross-account IAM roles, a least-privilege CI policy, and fixing an IAM cross-account bug.

Detailed writeups and answers to all the written questions are in [NOTES.md](file:///Users/apple/Desktop/Assignment/NOTES.md).

---

## Repository Layout

```
.
├── NOTES.md                     # Written answers, architectural explanations, and bug analysis
├── task1_ec2/                   # 5 EC2 instances driven from a single map variable
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
├── task2_backend/               # S3 + DynamoDB remote state backend configuration
│   ├── backend.tf               # Backend declaration for Task 1
│   └── state_backend_infra.tf   # Provisioning code for the S3 bucket & DynamoDB table
├── task3_iam/                   # Cross-account IAM setup (Account A and Account B)
│   ├── account_a.tf             # Groups (group1, group2) and Roles (roleA, roleB)
│   ├── account_b.tf             # Role (roleC) with single-bucket access
│   ├── variables.tf
│   └── outputs.tf
├── task4_least_privilege/       # Scoped IAM policy for the CI pipeline
│   ├── ci_least_privilege_policy.json
│   ├── ci_policy.tf
│   └── variables.tf
└── task5_bug_fix/               # Fix and explanation for the broken cross-account snippet
    ├── broken_original.tf.example
    └── fixed_roleC.tf
```

---

## Tasks Overview

### Task 1 — Multi-Instance EC2 Provisioning (`task1_ec2/`)
- Provisions 5 EC2 instances with distinct instance types, root volume types (`gp2`, `gp3`, `io2`, `standard`, `io1`), volume sizes, and key pairs.
- Driven entirely from a single map variable (`var.instances`).
- Accidental deletion protection (`lifecycle { prevent_destroy = true }`) is placed on `prod-database` (`c5.large` with `io2` storage).
- Outputs maps for `instance_name -> instance_id` and `instance_name -> private_ip`.

### Task 2 — Remote State & Locking (`task2_backend/`)
- `backend.tf`: Configures the S3 backend with DynamoDB state locking.
- `state_backend_infra.tf`: Sets up the S3 bucket (versioning, SSE-KMS, public access block) and DynamoDB table with `LockID` primary key.
- [NOTES.md](file:///Users/apple/Desktop/Assignment/NOTES.md#task-2--remote-state--locking) explains what happens when two developers run `apply` at the same time with local state, and how S3 + DynamoDB avoids race conditions and state corruption.

### Task 3 — Multi-Account IAM (`task3_iam/`)
- **Account A (`000000000000`)**:
  - `group1`: Programmatic-only access for `engine` and `ci`.
  - `group2`: Console and CLI access for named users (`alice`, `bob`).
  - `roleA`: Admin access to all AWS services except `iam:*` and `organizations:*`.
  - `roleB`: Allowed only to assume `roleC` in Account B.
- **Account B (`111111111111`)**:
  - `roleC`: Full access to a single named bucket, assumable only by `roleB` from Account A.
- [NOTES.md](file:///Users/apple/Desktop/Assignment/NOTES.md#task-3--multi-account-iam--cross-account-access) discusses alternatives to static IAM access keys in production (OIDC federation, compute-attached roles, IAM Roles Anywhere) and explains why trusting Account A root vs `roleB`'s specific ARN matters.

### Task 4 — Least-Privilege Policy Writing (`task4_least_privilege/`)
- Scoped IAM policy for the `ci` user allowing only:
  - Pushing images to a specific ECR repo.
  - Updating task definitions and deploying to a specific ECS service.
  - Read-only access to a specific S3 build artifacts bucket.
  - Scoped `iam:PassRole` restricted to ECS task execution roles.
- [NOTES.md](file:///Users/apple/Desktop/Assignment/NOTES.md#task-4--least-privilege-policy-writing) details what was left out (no wildcard actions, no delete operations, no broad managed policies) and why.

### Task 5 — Find and Fix the Bug (`task5_bug_fix/`)
- Fixed snippet in `fixed_roleC.tf`:
  1. Corrected `user/roleB` to `role/roleB` in the trust policy principal ARN.
  2. Scoped S3 permissions from `Resource = "*"` to the single named bucket and its objects (`arn:aws:s3:::<bucket>` and `arn:aws:s3:::<bucket>/*`).
- Full explanation documented in [NOTES.md](file:///Users/apple/Desktop/Assignment/NOTES.md#task-5--find-and-fix-the-bug).

---

## How to Validate

Each task directory contains self-contained Terraform code that can be validated with the standard CLI:

```bash
# Example: Validate Task 1
cd task1_ec2
terraform init -backend=false
terraform validate

# Example: Validate Task 4
cd ../task4_least_privilege
terraform init
terraform validate

# Example: Validate Task 5
cd ../task5_bug_fix
terraform init
terraform validate
```
