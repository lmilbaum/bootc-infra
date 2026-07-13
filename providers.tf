provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "bootc-poc"
      ManagedBy   = "Terraform"
      Environment = "dev"
    }
  }
}