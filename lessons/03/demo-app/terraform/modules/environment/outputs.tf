output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "client_service_name" {
  value = aws_ecs_service.client.name
}

output "server_service_name" {
  value = aws_ecs_service.server.name
}

output "db_service_name" {
  value = aws_ecs_service.db.name
}

output "deploy_user_access_key_id" {
  value = aws_iam_access_key.jenkins_deploy.id
}

output "deploy_user_secret_access_key" {
  value     = aws_iam_access_key.jenkins_deploy.secret
  sensitive = true
}

output "client_public_ip_hint" {
  description = "How to find the client's current public IP after a deploy (it changes every deployment — there is no load balancer in this lab setup)."
  value       = "aws ecs list-tasks --cluster ${aws_ecs_cluster.this.name} --service-name client | then describe-tasks | then describe-network-interfaces — see the walkthrough for the full one-liner."
}
