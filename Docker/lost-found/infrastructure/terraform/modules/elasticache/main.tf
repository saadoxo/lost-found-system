resource "aws_security_group" "redis" {
  name        = "${var.project}-redis-sg-${var.environment}"
  description = "ElastiCache Redis - accept from ECS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.ecs_sg_id]
    description     = "Redis from ECS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-redis-sg-${var.environment}"
  })
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-redis-subnet-group-${var.environment}"
  subnet_ids = var.private_subnet_ids
  tags       = var.common_tags
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.project}-redis-${var.environment}"
  description                = "Redis cluster for session management and caching"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
  engine_version             = "7.0"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = merge(var.common_tags, {
    Name = "${var.project}-redis-${var.environment}"
  })
}
