output "group1_name" {
  description = "Name of Group 1 (CLI/programmatic-only access)"
  value       = aws_iam_group.group1.name
}

output "group2_name" {
  description = "Name of Group 2 (Full Console and CLI access)"
  value       = aws_iam_group.group2.name
}

output "roleA_arn" {
  description = "ARN of Role A in Account A (Admin except IAM)"
  value       = aws_iam_role.roleA.arn
}

output "roleB_arn" {
  description = "ARN of Role B in Account A (Assume roleC only)"
  value       = aws_iam_role.roleB.arn
}

output "roleC_arn" {
  description = "ARN of Role C in Account B (Single-bucket full access)"
  value       = aws_iam_role.roleC.arn
}
