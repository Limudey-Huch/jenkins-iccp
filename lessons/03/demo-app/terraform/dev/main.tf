terraform {
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

# Reads the repos created once by terraform/shared/ — doesn't create or own
# them, so running this in two environments never conflicts.
data "aws_ecr_repository" "client" {
  name = "jewelry-client"
}

data "aws_ecr_repository" "server" {
  name = "jewelry-server"
}

module "environment" {
  source = "../modules/environment"

  environment           = "dev"
  aws_region            = var.aws_region
  client_repository_url = data.aws_ecr_repository.client.repository_url
  server_repository_url = data.aws_ecr_repository.server.repository_url
  client_image_tag      = var.client_image_tag
  server_image_tag      = var.server_image_tag
  desired_count         = 1
}
