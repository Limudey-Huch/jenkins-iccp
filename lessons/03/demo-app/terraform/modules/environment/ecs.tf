resource "aws_ecs_cluster" "this" {
  name = "jewelry-${var.environment}-cluster"
}

resource "aws_cloudwatch_log_group" "client" {
  name              = "/ecs/jewelry-${var.environment}/client"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "server" {
  name              = "/ecs/jewelry-${var.environment}/server"
  retention_in_days = 3
}

resource "aws_cloudwatch_log_group" "db" {
  name              = "/ecs/jewelry-${var.environment}/db"
  retention_in_days = 3
}

# --- db ---------------------------------------------------------------

resource "aws_ecs_task_definition" "db" {
  family                   = "jewelry-${var.environment}-db"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  # Fargate defaults to X86_64. Images built on an ARM-based Jenkins host
  # (e.g. Apple Silicon under virtualization) are ARM64-only, so every task
  # definition here explicitly requests ARM64 Fargate capacity to match —
  # native, no QEMU emulation needed, and ARM64 Fargate is slightly cheaper
  # too. If your Jenkins build host is x86_64 instead, delete these blocks.
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name         = "db"
      image        = "postgres:16-alpine"
      portMappings = [{ containerPort = 5432, protocol = "tcp" }]
      environment = [
        { name = "POSTGRES_DB", value = "jewelry" },
        { name = "POSTGRES_USER", value = "jewelry" },
      ]
      secrets = [
        { name = "POSTGRES_PASSWORD", valueFrom = aws_secretsmanager_secret.db_password.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.db.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "db"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "db" {
  name            = "db"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.db.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.db.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.db.arn
  }
}

# --- server -------------------------------------------------------------

resource "aws_ecs_task_definition" "server" {
  family                   = "jewelry-${var.environment}-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name         = "server"
      image        = "${var.server_repository_url}:${var.server_image_tag}"
      portMappings = [{ containerPort = 5000, protocol = "tcp" }]
      environment = [
        { name = "DB_HOST", value = "db.jewelry.local" },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = "jewelry" },
        { name = "DB_USER", value = "jewelry" },
      ]
      secrets = [
        { name = "DB_PASSWORD", valueFrom = aws_secretsmanager_secret.db_password.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.server.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "server"
        }
      }
    }
  ])

  depends_on = [aws_ecs_service.db]
}

resource "aws_ecs_service" "server" {
  name            = "server"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.server.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.server.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.server.arn
  }
}

# --- client ---------------------------------------------------------------

resource "aws_ecs_task_definition" "client" {
  family                   = "jewelry-${var.environment}-client"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name         = "client"
      image        = "${var.client_repository_url}:${var.client_image_tag}"
      portMappings = [{ containerPort = 80, protocol = "tcp" }]
      environment = [
        { name = "SERVER_ADDR", value = "server.jewelry.local:5000" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.client.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "client"
        }
      }
    }
  ])

  depends_on = [aws_ecs_service.server]
}

resource "aws_ecs_service" "client" {
  name            = "client"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.client.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public.id]
    security_groups  = [aws_security_group.client.id]
    assign_public_ip = true
  }
}
