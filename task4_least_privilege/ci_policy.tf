# Task 4: Least-privilege IAM policy for CI pipeline

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_iam_policy_document" "ci_least_privilege" {
  # ECR registry authentication
  # Note: AWS requires Resource = "*" for GetAuthorizationToken as it's an account-level call
  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push image to the specific repository only
  statement {
    sid    = "ECRPushImageToSpecificRepo"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/${var.ecr_repository_name}"
    ]
  }

  # Register and describe task definitions
  statement {
    sid    = "ECSRegisterTaskDefinition"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition"
    ]
    resources = ["*"]
  }

  # Update only the target ECS service
  statement {
    sid    = "ECSUpdateSpecificService"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices"
    ]
    resources = [
      "arn:aws:ecs:${var.aws_region}:${var.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
    ]
  }

  # Pass task execution and task roles to ECS tasks only
  statement {
    sid     = "IAMPassRoleToECSTasksOnly"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      var.ecs_execution_role_arn,
      var.ecs_task_role_arn
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # Read-only access to the build artifacts bucket (listing & metadata)
  statement {
    sid    = "S3ListBuildArtifactsBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::${var.build_artifacts_bucket}"
    ]
  }

  # Read-only access to download build artifact objects
  statement {
    sid    = "S3ReadBuildArtifactsObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [
      "arn:aws:s3:::${var.build_artifacts_bucket}/*"
    ]
  }
}

resource "aws_iam_policy" "ci_least_privilege" {
  name        = "ci-least-privilege-pipeline-policy"
  description = "Scoped policy for CI pipeline: ECR push, ECS deploy, and S3 read-only"
  policy      = data.aws_iam_policy_document.ci_least_privilege.json
}

# Attach to the ci user
resource "aws_iam_user_policy_attachment" "ci_attachment" {
  user       = "ci"
  policy_arn = aws_iam_policy.ci_least_privilege.arn
}

output "ci_policy_arn" {
  description = "ARN of the least-privilege CI policy"
  value       = aws_iam_policy.ci_least_privilege.arn
}
