terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "ci_artifacts" {
  bucket = "jenkins-iccp-ci-artifacts-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "ci_artifacts" {
  bucket                  = aws_s3_bucket.ci_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_user" "jenkins" {
  name = "jenkins-s3-demo"
}

resource "aws_iam_access_key" "jenkins" {
  user = aws_iam_user.jenkins.name
}

# Least privilege: this user can ONLY PutObject into this one bucket.
# It cannot list other buckets, delete objects, or touch any other AWS service.
resource "aws_iam_user_policy" "jenkins_s3_put_only" {
  name = "jenkins-s3-put-only"
  user = aws_iam_user.jenkins.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.ci_artifacts.arn}/*"
      }
    ]
  })
}
