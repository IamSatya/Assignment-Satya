# Account A (000000000000) IAM resources

# Group 1: Programmatic / CLI only access
# Members: engine, ci
resource "aws_iam_group" "group1" {
  name = "group1"
}

resource "aws_iam_user" "group1_members" {
  for_each = toset(["engine", "ci"])
  name     = each.key

  tags = {
    Environment = "production"
    AccessType  = "programmatic"
  }
}

resource "aws_iam_group_membership" "group1_membership" {
  name  = "group1-membership"
  group = aws_iam_group.group1.name
  users = [for u in aws_iam_user.group1_members : u.name]
}

# Block console access for group1 users to enforce CLI/API-only access
resource "aws_iam_group_policy" "deny_console_access" {
  name  = "deny-console-access"
  group = aws_iam_group.group1.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyConsoleLoginAndPasswordManagement"
        Effect = "Deny"
        Action = [
          "iam:CreateLoginProfile",
          "iam:UpdateLoginProfile",
          "iam:ChangePassword"
        ]
        Resource = "*"
      }
    ]
  })
}

# Group 2: Console + CLI access
# Members: named human users (alice, bob)
resource "aws_iam_group" "group2" {
  name = "group2"
}

resource "aws_iam_user" "group2_members" {
  for_each = toset(var.group2_users)
  name     = each.key

  tags = {
    Environment = "production"
    AccessType  = "console-and-cli"
  }
}

resource "aws_iam_group_membership" "group2_membership" {
  name  = "group2-membership"
  group = aws_iam_group.group2.name
  users = [for u in aws_iam_user.group2_members : u.name]
}

# roleA: Admin access to all AWS services except IAM & Organizations
data "aws_iam_policy_document" "roleA_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_a_id}:root"]
    }
  }
}

resource "aws_iam_role" "roleA" {
  name               = "roleA"
  assume_role_policy = data.aws_iam_policy_document.roleA_trust.json
  description        = "Admin access to all services except IAM and Organizations"
}

resource "aws_iam_role_policy" "roleA_policy" {
  name = "admin-except-iam"
  role = aws_iam_role.roleA.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowAllServices"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      },
      {
        Sid    = "ExplicitDenyIAMAndOrganizations"
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# roleB: Only allowed to assume roleC in Account B
data "aws_iam_policy_document" "roleB_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_a_id}:root"]
    }
  }
}

resource "aws_iam_role" "roleB" {
  name               = "roleB"
  assume_role_policy = data.aws_iam_policy_document.roleB_trust.json
  description        = "Account A role whose only permission is assuming roleC in Account B"
}

resource "aws_iam_role_policy" "roleB_assume_roleC" {
  name = "assume-roleC-only"
  role = aws_iam_role.roleB.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowAssumeRoleCInAccountB"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.account_b_id}:role/roleC"
      }
    ]
  })
}
