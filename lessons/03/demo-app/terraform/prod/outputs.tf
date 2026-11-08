output "cluster_name" {
  value = module.environment.cluster_name
}

output "client_service_name" {
  value = module.environment.client_service_name
}

output "server_service_name" {
  value = module.environment.server_service_name
}

output "db_service_name" {
  value = module.environment.db_service_name
}

output "deploy_user_access_key_id" {
  value = module.environment.deploy_user_access_key_id
}

output "deploy_user_secret_access_key" {
  value     = module.environment.deploy_user_secret_access_key
  sensitive = true
}

output "client_public_ip_hint" {
  value = module.environment.client_public_ip_hint
}
