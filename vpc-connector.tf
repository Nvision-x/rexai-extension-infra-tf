# ============================================================================
# Shared VPC Connector for App Runner Services
# ============================================================================
# This VPC connector is shared between frontend and backend App Runner services
# for outbound traffic to VPC resources

# ----------------------------------------------------------------------------
# Shared VPC Connector
# ----------------------------------------------------------------------------
resource "aws_apprunner_vpc_connector" "shared" {
  vpc_connector_name = "${var.name_prefix}-shared-vpc-connector"
  subnets            = var.private_subnets
  security_groups    = [aws_security_group.shared_vpc_connector_sg.id]

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-shared-vpc-connector"
      Purpose = "Shared VPC connector for App Runner services"
    }
  )
}

# ----------------------------------------------------------------------------
# Security Group for Shared VPC Connector
# ----------------------------------------------------------------------------
resource "aws_security_group" "shared_vpc_connector_sg" {
  name        = "${var.name_prefix}-shared-vpc-connector-sg"
  description = "Security group for shared App Runner VPC connector"
  vpc_id      = var.vpc_id

  # Egress rules for VPC connector
  # Allow HTTPS to VPC resources
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow HTTPS to VPC resources"
  }

  # Allow HTTP to VPC resources (if needed)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow HTTP to VPC resources"
  }

  # Allow access to OpenSearch
  egress {
    from_port   = 9200
    to_port     = 9300
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow OpenSearch connections"
  }

  # Allow access to RDS/Aurora (MySQL)
  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow MySQL/Aurora connections"
  }

  # Allow access to PostgreSQL
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow PostgreSQL connections"
  }

  # Allow access to Redis/ElastiCache
  egress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow Redis/ElastiCache connections"
  }

  # Allow DNS resolution
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow DNS resolution (UDP)"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow DNS resolution (TCP)"
  }

  # Allow outbound HTTPS to internet for external APIs
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS to internet"
  }

  # Allow access to AWS services via VPC endpoints
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.s3.id]
    description     = "Allow HTTPS to S3 via VPC endpoint"
  }

  tags = merge(
    var.tags,
    {
      Name    = "${var.name_prefix}-shared-vpc-connector-sg"
      Purpose = "Shared VPC Connector Security Group"
    }
  )
}

# Data source for S3 prefix list
data "aws_prefix_list" "s3" {
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.${var.region}.s3"]
  }
}

# ----------------------------------------------------------------------------
# Outputs for the shared VPC connector
# ----------------------------------------------------------------------------
output "shared_vpc_connector_arn" {
  description = "ARN of the shared VPC connector"
  value       = aws_apprunner_vpc_connector.shared.arn
}

output "shared_vpc_connector_status" {
  description = "Status of the shared VPC connector"
  value       = aws_apprunner_vpc_connector.shared.status
}

output "shared_vpc_connector_sg_id" {
  description = "Security group ID for the shared VPC connector"
  value       = aws_security_group.shared_vpc_connector_sg.id
}