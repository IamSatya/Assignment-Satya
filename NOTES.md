# DevOps Assignment Notes

This document contains the explanations and design rationale for each task in the assignment.

---

## Task 1 — Multi-Instance EC2 Provisioning

### Accidental Deletion Protection
I chose the `prod-database` instance for the `prevent_destroy` lifecycle rule.

**Why this instance:**
In this architecture, instances like `web-frontend`, `api-backend`, and `analytics-worker` are stateless application and worker nodes. If any of those are terminated or recreated, we can easily spin up replacements behind a load balancer or worker queue without data loss.

The `prod-database` instance is fundamentally different:
- It is stateful and stores persistent application data.
- It uses a 50GB `io2` volume with 3,000 provisioned IOPS.
- Tearing it down—whether via an accidental `terraform destroy`, an unintentional AMI change, or a variable misconfiguration—causes immediate downtime, requires restoring from backups, and risks write-loss.

Adding `lifecycle { prevent_destroy = true }` acts as a hard safety guardrail in Terraform. Any plan or apply that would destroy or force-replace this instance will fail immediately before touching AWS.

### Handling `lifecycle` with `for_each`
One specific constraint in Terraform HCL is that the `lifecycle` block is evaluated during graph construction and does not accept dynamic values (e.g. `prevent_destroy = each.value.prevent_destroy` will throw a syntax error).

To keep the requirement of driving all 5 instances from a **single input variable** (`var.instances`) while only protecting the database:
1. I used two `aws_instance` resource blocks (`protected` and `standard`).
2. Both blocks iterate over `var.instances` using a `for_each` filter:
   - `protected` selects items where `prevent_destroy == true` and includes the `lifecycle` block.
   - `standard` selects items where `prevent_destroy == false`.
3. In `outputs.tf`, I merged both maps so the root module still outputs a clean, unified map of instance IDs and private IPs.

---

## Task 2 — Remote State & Locking

### 1. What happens with local state when two people run `apply` at the same time?
When state is stored locally (`terraform.tfstate`), there is no locking or coordination between teammates. If Alice and Bob run `terraform apply` concurrently:

1. **Both read the same state file at the start**: Both plans are generated against the exact same snapshot of the infrastructure.
2. **Conflicting AWS API calls**: Both machines start sending API calls to AWS simultaneously. If they are modifying the same resources, you get race conditions—like naming collisions, conflicting resource updates, or AWS API rate-limiting errors.
3. **State overwrites and orphaned resources**: The most damaging issue happens when the runs finish. Whoever finishes last overwrites the local state file. 
   - If Alice creates 3 new resources and finishes first, her changes are written to state.
   - If Bob finishes a minute later, Bob's machine writes his state over Alice's.
   - Alice's 3 resources still exist and run in AWS (incurring costs), but they are completely wiped out of `terraform.tfstate`. They become "ghost" or orphaned resources that Terraform no longer manages.

### 2. How the S3 + DynamoDB backend fixes this
1. **Distributed State Locking (DynamoDB)**:
   - The DynamoDB table uses `LockID` as its primary hash key.
   - When Alice runs `terraform apply`, Terraform writes an item into DynamoDB with a unique lock ID, her hostname, and timestamp.
   - When Bob runs `terraform apply` while Alice's run is active, Terraform tries to acquire the lock, receives a `ConditionalCheckFailedException` from DynamoDB, and immediately halts before reading or modifying anything.
   - Once Alice's run finishes (or fails cleanly), Terraform deletes the lock item so the next person can proceed.
2. **Centralized Single Source of Truth (S3)**:
   - The state file lives in a single shared S3 bucket instead of individual laptops.
   - S3 versioning is enabled, so every single state modification creates a new immutable version. If a bad apply ever corrupts the state file, we can inspect previous versions and roll back in seconds.
   - Encryption at rest (SSE-KMS) and a public access block ensure the state file (which may contain sensitive IDs and attributes) remains secure.

---

## Task 3 — Multi-Account IAM & Cross-Account Access

### 1. Would you actually give `engine` and `ci` IAM users with access keys in production?
**No, I would not.**

In production, using IAM users with static access keys (`AKIA...`) for automated jobs is something I actively avoid. Static keys are permanent credentials with no built-in expiration. In practice, they often get leaked—committed to git repos, printed in CI build logs, or left unencrypted on developer laptops—and teams rarely rotate them.

#### What I would do instead:

1. **For CI pipelines (`ci`)**:
   - **OIDC Federation (Preferred)**: If using GitHub Actions, GitLab CI, or CircleCI, set up an OpenID Connect (OIDC) identity provider in AWS IAM. The CI workflow requests a short-lived signed JWT from the provider and calls `sts:AssumeRoleWithWebIdentity`. AWS STS checks the repo and branch in the trust policy and returns temporary credentials (15–60 min). No AWS credentials ever need to be stored in GitHub secrets.
   - **Self-Hosted VPC Runners**: If the company runs self-hosted runners inside AWS (like GitHub Actions Runner Controller on EKS or EC2), attach an IAM role directly to the compute instance via Instance Profile or EKS Pod Identity. The runner fetches temporary credentials automatically from IMDSv2.
2. **For automated backend services (`engine`)**:
   - **AWS Compute**: If the service runs on AWS (EC2, ECS, or EKS), attach an IAM role directly to the resource:
     - EC2: IAM Instance Profile (using IMDSv2)
     - ECS: Task Role (`task_role_arn`)
     - EKS: EKS Pod Identity or IRSA (IAM Roles for Service Accounts)
     AWS generates, injects, and rotates the temporary credentials automatically.
   - **On-Premises or Hybrid**: If `engine` runs outside AWS (on-prem datacenter or another cloud), use **AWS IAM Roles Anywhere** with X.509 certificates from your internal CA, or use **HashiCorp Vault's dynamic AWS secrets engine** to generate short-lived STS credentials on demand.
   - **Legacy fallback**: If an old tool strictly requires static keys and can't be updated, store the access key in AWS Secrets Manager and set up a Lambda function to automatically rotate the key every 14 to 30 days.

---

### 2. In `roleC`'s trust policy, why does it matter whether you trust Account A root vs `roleB`'s specific ARN?

- **If you trust Account A root (`arn:aws:iam::000000000000:root`)**:
  You are trusting the **entire account**, not a specific role. Account B is essentially delegating authorization decisions to whoever manages Account A. If any admin in Account A gives permission for `alice`, `bob`, or the `ci` user to call `sts:AssumeRole` on `roleC`, they will be able to assume it. Account B has no say or visibility into who in Account A is actually using the role.
- **If you trust `roleB`'s specific ARN (`arn:aws:iam::000000000000:role/roleB`)**:
  You enforce strict least privilege and a required two-way handshake:
  1. Account A must grant `roleB` permission to assume `roleC`.
  2. Account B's trust policy explicitly permits *only* `roleB`.
  
  Even if someone in Account A accidentally or intentionally grants `sts:AssumeRole` on `roleC` to `alice` or `ci`, AWS STS will reject the request because `roleC`'s trust policy strictly requires the caller to be `roleB`.

---

## Task 4 — Least-Privilege Policy Writing

### Scope of the CI Policy
The policy in `task4_least_privilege/` is scoped strictly to the three actions requested:
1. **ECR Image Push**:
   - Scoped to the specific repository ARN (`arn:aws:ecr:...:repository/my-app-repo`).
   - Allows only image layer checks, uploads, and putting images.
   - The only action with `Resource = "*"` is `ecr:GetAuthorizationToken`, which AWS requires because the authentication token API operates at the registry/account level, not repository level.
2. **ECS Deployment**:
   - Allows registering task definitions (`ecs:RegisterTaskDefinition`).
   - Allows updating only the specific target service (`ecs:UpdateService` on `arn:aws:ecs:...:service/production-cluster/my-app-service`).
   - Grants `iam:PassRole` restricted specifically to the ECS task and execution role ARNs, with a condition ensuring the role can only be passed to `ecs-tasks.amazonaws.com`.
3. **S3 Build Artifacts**:
   - Strictly read-only (`s3:GetObject`, `s3:GetObjectVersion`, `s3:ListBucket`, `s3:GetBucketLocation`) scoped to the specific artifacts bucket.

### What was left out and why
- **No managed policies (`AdministratorAccess`, `PowerUserAccess`)**: These grant wide-open administrative or write access across all services. A compromised build step could create rogue EC2 instances, change security groups, or alter databases.
- **No wildcards on actions (`ecr:*`, `ecs:*`, `s3:*`)**: 
  - On ECR: Excluded administrative actions like `ecr:DeleteRepository`, `ecr:BatchDeleteImage`, or changing repo policies.
  - On ECS: Excluded cluster/service deletion (`ecs:DeleteCluster`, `ecs:DeleteService`) and manual container termination (`ecs:StopTask`).
- **No S3 write/delete permissions**: The assignment specified *reading* build artifacts. Leaving out `s3:PutObject` and `s3:DeleteObject` prevents a compromised CI runner or rogue script from overwriting golden artifacts or tampering with historical builds.
- **No wildcard `iam:PassRole`**: Allowing `iam:PassRole` on `Resource = "*"` is a major privilege escalation risk (a developer or CI script could attach an administrator role to an ECS task). The policy restricts `iam:PassRole` to only the specific task execution and application role ARNs, and only for the `ecs-tasks.amazonaws.com` service.

---

## Task 5 — Find and Fix the Bug

The provided snippet had two distinct bugs:

### Bug 1: Trust Policy specified `user/roleB` instead of `role/roleB`
- **What was wrong**:
  ```hcl
  identifiers = ["arn:aws:iam::000000000000:user/roleB"]
  ```
- **Why it failed**:
  In AWS IAM, users and roles have separate ARN namespaces:
  - IAM User: `arn:aws:iam::<account>:user/<name>`
  - IAM Role: `arn:aws:iam::<account>:role/<name>`
  
  `roleB` was created as an IAM Role in Account A, not an IAM User. When `roleB` in Account A calls `sts:AssumeRole` targeting `roleC`, STS checks the caller's ARN (`arn:aws:iam::000000000000:role/roleB`). Because the trust policy expected `:user/roleB`, STS rejects the call with `AccessDenied` (or Terraform/IAM fails with an invalid principal error if no user named `roleB` exists).
- **The fix**:
  Change `user/roleB` to `role/roleB`:
  ```hcl
  identifiers = ["arn:aws:iam::000000000000:role/roleB"]
  ```

### Bug 2: Permissions policy granted `s3:*` on `Resource = "*"`
- **What was wrong**:
  ```hcl
  Action   = "s3:*"
  Resource = "*"
  ```
- **Why it failed**:
  The requirement in Task 3 explicitly called for full access to a **single named S3 bucket**, not every bucket in Account B. Using `Resource = "*"` gives `roleC` full access across every existing and future bucket in Account B, violating least privilege.
- **The fix**:
  Scope the resource block to the bucket ARN and the bucket's objects:
  ```hcl
  Resource = [
    "arn:aws:s3:::account-b-production-data",
    "arn:aws:s3:::account-b-production-data/*"
  ]
  ```

The corrected file is in `task5_bug_fix/fixed_roleC.tf`.
