# Applied ONCE, by the instructor, before class — not per-environment.
# Holds only what's genuinely shared across dev and prod: the container
# registries. Images are built once and promoted (by tag) through
# environments, so the registry itself isn't duplicated — unlike the VPC,
# which dev/prod each get their own copy of, for full network isolation.

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

resource "aws_ecr_repository" "client" {
  name                 = "jewelry-client"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "server" {
  name                 = "jewelry-server"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
