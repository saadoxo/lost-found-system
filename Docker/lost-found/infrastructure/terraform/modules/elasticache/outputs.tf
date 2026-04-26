output "redis_endpoint" {
  value     = aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive = true
}

output "redis_port" {
  value = 6379
}

output "redis_sg_id" {
  value = aws_security_group.redis.id
}
