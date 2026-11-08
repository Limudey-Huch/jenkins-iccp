variable "environment" {
  description = "Short environment name, e.g. \"dev\" or \"prod\". Used to name and isolate every resource this module creates."
  type        = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "client_repository_url" {
  description = "ECR repository URL for the client image (from the shared/ stack's output)."
  type        = string
}

variable "server_repository_url" {
  description = "ECR repository URL for the server image (from the shared/ stack's output)."
  type        = string
}

variable "client_image_tag" {
  type    = string
  default = "latest"
}

variable "server_image_tag" {
  type    = string
  default = "latest"
}

variable "desired_count" {
  description = "Number of running tasks per service in this environment."
  type        = number
  default     = 1
}
