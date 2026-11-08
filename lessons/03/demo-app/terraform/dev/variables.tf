variable "aws_region" {
  default = "us-east-1"
}

variable "client_image_tag" {
  description = "Overridden by Jenkins at deploy time, e.g. -var=\"client_image_tag=dev-23\"."
  default     = "latest"
}

variable "server_image_tag" {
  default = "latest"
}
