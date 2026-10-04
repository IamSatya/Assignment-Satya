variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "account_id" {
  type        = string
  description = "AWS Account ID"
  default     = "000000000000"
}

variable "ecr_repository_name" {
  type        = string
  description = "Specific ECR repository name that CI is allowed to push images to"
  default     = "my-app-repo"
}

variable "ecs_cluster_name" {
  type        = string
  description = "Specific ECS cluster name"
  default     = "production-cluster"
}

variable "ecs_service_name" {
  type        = string
  description = "Specific ECS service name to deploy to"
  default     = "my-app-service"
}

variable "ecs_execution_role_arn" {
  type        = string
  description = "ARN of the ECS Task Execution Role that CI is permitted to pass"
  default     = "arn:aws:iam::000000000000:role/my-app-ecs-execution-role"
}

variable "ecs_task_role_arn" {
  type        = string
  description = "ARN of the ECS Task Role that CI is permitted to pass"
  default     = "arn:aws:iam::000000000000:role/my-app-ecs-task-role"
}

variable "build_artifacts_bucket" {
  type        = string
  description = "Specific S3 bucket containing build artifacts (Read-only access)"
  default     = "ci-build-artifacts-bucket"
}
