terraform {
  backend "s3" {
    bucket         = "my-company-terraform-state-us-east-1"
    key            = "assignment/task1-ec2/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
