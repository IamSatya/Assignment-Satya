# DevOps Assignment Solutions

This repository contains my solutions for the 5 DevOps assignment tasks, covering EC2 provisioning with Terraform, remote state locking with S3 and DynamoDB, cross-account IAM roles, a least-privilege CI policy, and fixing an IAM cross-account bug.

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
