output "client_repository_url" {
  value = aws_ecr_repository.client.repository_url
}

output "server_repository_url" {
  value = aws_ecr_repository.server.repository_url
}
