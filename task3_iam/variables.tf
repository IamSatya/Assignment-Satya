variable "account_a_id" {
  type        = string
  description = "AWS Account ID for Account A (Source Account)"
  default     = "000000000000"
}

variable "account_b_id" {
  type        = string
  description = "AWS Account ID for Account B (Destination Account)"
  default     = "111111111111"
}

variable "named_s3_bucket" {
  type        = string
  description = "Single named S3 bucket in Account B accessible by roleC"
  default     = "account-b-shared-data-bucket"
}

variable "group2_users" {
  type        = list(string)
  description = "Named human users for group2 with console and CLI access"
  default     = ["alice", "bob"]
}
