# Two separate IAM identities, two separate jobs:
#
# 1. ecsTaskExecutionRole — used BY Fargate itself (not by Jenkins) to pull
#    images from ECR, read the DB password secret, and write logs. Standard,
#    low-risk, AWS-managed policy — every ECS task in every environment needs
#    this to even start.
#
# 2. jenkins-deploy-<environment> — used BY the Jenkins pipeline to push
#    images and trigger a deployment. This is the interesting one: it is
#    scoped to THIS environment's ECS cluster/services only. A leaked
#    jenkins-deploy-dev credential cannot touch anything in prod — it has no
#    permission to, not even to list prod's resources.

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ecs_execution" {
  name = "jewelry-${var.environment}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "jewelry-${var.environment}-read-db-secret"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.db_password.arn
    }]
  })
}

resource "aws_iam_user" "jenkins_deploy" {
  name = "jenkins-deploy-${var.environment}"
}

resource "aws_iam_access_key" "jenkins_deploy" {
  user = aws_iam_user.jenkins_deploy.name
}

resource "aws_iam_user_policy" "jenkins_deploy" {
  name = "jewelry-${var.environment}-deploy-policy"
  user = aws_iam_user.jenkins_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # ECR auth tokens are account-wide by design — AWS doesn't support
        # restricting this action to specific repositories. Worth calling
        # out: least privilege has limits set by the provider's own API, not
        # just by how carefully you write the policy.
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # Also account-wide only (no resource-level support) — used by the
        # Jenkinsfiles to build the ECR registry hostname (<account>.dkr.ecr.
        # <region>.amazonaws.com) without needing ecr:DescribeRepositories.
        Sid      = "AllowCallerIdentity"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
      {
        Sid    = "EcrPushToTheseReposOnly"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          # Read-only, but still needed for a *push*: modern Docker (BuildKit)
          # attaches a provenance/attestation manifest to every image by
          # default, and finishing that manifest requires reading back
          # existing image data mid-push, not just writing new layers.
          "ecr:BatchGetImage",
        ]
        Resource = [
          "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/jewelry-client",
          "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/jewelry-server",
        ]
      },
      {
        # Another account-wide-only action: ECS doesn't support restricting
        # RegisterTaskDefinition by cluster or service.
        Sid      = "RegisterTaskDefinition"
        Effect   = "Allow"
        Action   = "ecs:RegisterTaskDefinition"
        Resource = "*"
      },
      {
        # Read-only, so scoped more loosely than the mutating actions above
        # on purpose — Lesson 04 uses this so a "main" pipeline can look up
        # what's currently running in an environment (e.g. "what server tag
        # is live in dev right now?") before triggering a promotion.
        Sid      = "DescribeTaskDefinitions"
        Effect   = "Allow"
        Action   = "ecs:DescribeTaskDefinition"
        Resource = "*"
      },
      {
        Sid    = "UpdateOnlyThisEnvironmentsServices"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.this.name}/*",
        ]
      },
      {
        Sid      = "PassOnlyThisEnvironmentsExecutionRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.ecs_execution.arn
      },
    ]
  })
}
