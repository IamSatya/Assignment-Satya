variable "aws_region" {
  type        = string
  description = "AWS Region to deploy resources"
  default     = "us-east-1"
}

variable "ami_id" {
  type        = string
  description = "Base AMI ID to use for the EC2 instances"
  default     = "ami-0c7217cdde317cfec" # Default Ubuntu 22.04 LTS in us-east-1
}

variable "instances" {
  type = map(object({
    instance_type    = string
    root_volume_type = string
    root_volume_size = number
    iops             = optional(number)
    throughput       = optional(number)
    key_name         = string
    environment      = string
    owner            = string
    prevent_destroy  = optional(bool, false)
  }))
  description = "Single input variable driving all EC2 instances with distinct types, volumes, sizes, and keys"
  default = {
    "web-frontend" = {
      instance_type    = "t3.micro"
      root_volume_type = "gp2"
      root_volume_size = 20
      key_name         = "key-web-frontend"
      environment      = "development"
      owner            = "frontend-team"
      prevent_destroy  = false
    }
    "api-backend" = {
      instance_type    = "t3.small"
      root_volume_type = "gp3"
      root_volume_size = 35
      key_name         = "key-api-backend"
      environment      = "staging"
      owner            = "backend-team"
      prevent_destroy  = false
    }
    "prod-database" = {
      instance_type    = "c5.large"
      root_volume_type = "io2"
      root_volume_size = 50
      iops             = 3000
      key_name         = "key-prod-database"
      environment      = "production"
      owner            = "dba-team"
      prevent_destroy  = true # Critical instance protected against accidental deletion
    }
    "analytics-worker" = {
      instance_type    = "m5.large"
      root_volume_type = "standard"
      root_volume_size = 75
      key_name         = "key-analytics-worker"
      environment      = "production"
      owner            = "data-analytics-team"
      prevent_destroy  = false
    }
    "cache-cluster" = {
      instance_type    = "r5.large"
      root_volume_type = "io1"
      root_volume_size = 100
      iops             = 4000
      key_name         = "key-cache-cluster"
      environment      = "production"
      owner            = "platform-team"
      prevent_destroy  = false
    }
  }
}
