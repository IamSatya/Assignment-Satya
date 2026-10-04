# Account B (111111111111) IAM resources
# roleC: Full access to a single named S3 bucket, assumable only by roleB in Account A

# Trust policy allowing only roleB from Account A
data "aws_iam_policy_document" "roleC_trust" {
  statement {
    sid     = "AllowOnlyRoleBFromAccountA"
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
  description        = "Role granting full access to a single S3 bucket, assumable only by roleB in Account A"
}

# Policy scoped strictly to the named bucket and its objects
resource "aws_iam_role_policy" "roleC_single_bucket_access" {
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
          "arn:aws:s3:::${var.named_s3_bucket}",
          "arn:aws:s3:::${var.named_s3_bucket}/*"
        ]
      }
    ]
  })
}
