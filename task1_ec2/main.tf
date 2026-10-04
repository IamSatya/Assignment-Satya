terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Protected instances requiring prevent_destroy = true
# (Terraform lifecycle blocks do not accept dynamic expressions inside for_each)
resource "aws_instance" "protected" {
  for_each = {
    for k, v in var.instances : k => v
    if try(v.prevent_destroy, false) == true
  }

  ami           = var.ami_id
  instance_type = each.value.instance_type
  key_name      = each.value.key_name

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    iops                  = lookup(each.value, "iops", null)
    throughput            = lookup(each.value, "throughput", null)
    delete_on_termination = true

    tags = {
      Name        = "${each.key}-root-volume"
      Environment = each.value.environment
      Owner       = each.value.owner
    }
  }

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Standard instances without destruction protection
resource "aws_instance" "standard" {
  for_each = {
    for k, v in var.instances : k => v
    if try(v.prevent_destroy, false) == false
  }

  ami           = var.ami_id
  instance_type = each.value.instance_type
  key_name      = each.value.key_name

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    iops                  = lookup(each.value, "iops", null)
    throughput            = lookup(each.value, "throughput", null)
    delete_on_termination = true

    tags = {
      Name        = "${each.key}-root-volume"
      Environment = each.value.environment
      Owner       = each.value.owner
    }
  }

  tags = {
    Name        = each.key
    Environment = each.value.environment
    Owner       = each.value.owner
  }
}
