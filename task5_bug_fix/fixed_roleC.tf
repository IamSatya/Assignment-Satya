# Task 5: Fixed cross-account IAM role configuration
# - Bug 1: roleB is an IAM role in Account A, so the principal identifier must use role/roleB instead of user/roleB.
# - Bug 2: Scope S3 permissions to the specific named bucket and objects instead of using wildcard Resource = "*".

variable "account_a_id" {
  type        = string
  description = "Account A ID"
  default     = "000000000000"
}

variable "named_bucket_name" {
  type        = string
  description = "Single named S3 bucket to which roleC is granted full access"
  default     = "account-b-production-data"
}

# Trust policy allowing only roleB from Account A
data "aws_iam_policy_document" "roleC_trust" {
  statement {
    sid     = "AllowRoleBFromAccountA"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_a_id}:role/roleB"]
    }
  }
}

resource "aws_iam_role" "roleC" {
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.roleC_trust.json
  description        = "Role C in Account B, assumable only by roleB from Account A"
}

# Scoped S3 permissions for the single named bucket
resource "aws_iam_role_policy" "roleC_s3" {
  name = "roleC-single-bucket-access"
  role = aws_iam_role.roleC.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "FullAccessToSingleNamedBucket"
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${var.named_bucket_name}",
          "arn:aws:s3:::${var.named_bucket_name}/*"
        ]
      }
    ]
  })
}
