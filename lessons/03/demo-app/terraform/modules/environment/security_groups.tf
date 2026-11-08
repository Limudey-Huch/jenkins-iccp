# Network segmentation, the same least-privilege principle as the IAM policies
# in this lesson — applied to the network instead. Each tier can only be
# reached by the tier directly in front of it, never skipped, never public
# unless it has to be:
#   internet -> client (80)
#   client   -> server (5000)
#   server   -> db (5432)

resource "aws_security_group" "client" {
  name_prefix = "jewelry-${var.environment}-client-"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Public web access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jewelry-${var.environment}-client-sg" }
}

resource "aws_security_group" "server" {
  name_prefix = "jewelry-${var.environment}-server-"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jewelry-${var.environment}-server-sg" }
}

resource "aws_security_group_rule" "server_ingress_from_client" {
  type                     = "ingress"
  from_port                = 5000
  to_port                  = 5000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.server.id
  source_security_group_id = aws_security_group.client.id
  description              = "Only the client service may reach the server - not the internet."
}

resource "aws_security_group" "db" {
  name_prefix = "jewelry-${var.environment}-db-"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jewelry-${var.environment}-db-sg" }
}

resource "aws_security_group_rule" "db_ingress_from_server" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.server.id
  description              = "Only the server service may reach the database - not the client, not the internet."
}
