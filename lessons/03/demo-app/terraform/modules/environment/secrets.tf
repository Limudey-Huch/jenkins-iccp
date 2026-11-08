# The database password never appears in the task definition, in the
# Jenkinsfile, or in any file in this repo — it's generated here, stored in
# Secrets Manager, and handed to the containers at startup via the task
# definition's `secrets` block (not `environment`). This is the same
# principle as the Jenkins Credentials Store earlier in this lesson, applied
# at the infrastructure layer instead of the CI layer: a secret a pipeline or
# container needs, but that no human ever has to type, copy, or see.

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "jewelry-${var.environment}-db-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}
