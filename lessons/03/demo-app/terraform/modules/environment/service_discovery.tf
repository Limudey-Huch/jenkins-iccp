# Private DNS so client -> server -> db can find each other by a stable name
# (server.jewelry.local, db.jewelry.local) instead of a Fargate task's public
# IP, which changes on every deployment. This namespace is scoped to this
# environment's own VPC, so "jewelry.local" resolves independently (and
# differently) inside dev's VPC vs. prod's VPC.

resource "aws_service_discovery_private_dns_namespace" "this" {
  name = "jewelry.local"
  vpc  = aws_vpc.this.id
}

resource "aws_service_discovery_service" "server" {
  name = "server"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_service_discovery_service" "db" {
  name = "db"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
}
