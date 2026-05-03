output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "alb_dns_name" {
  description = "Public ALB DNS name — this is your app's entry point"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.elasticache.redis_endpoint
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "images_bucket_name" {
  description = "S3 bucket for item images"
  value       = module.s3.images_bucket_name
}

output "auth_service_name" {
  value = module.ecs_services.auth_service_name
}

output "log_group_name" {
  value = module.ecs_services.log_group_name
}

output "item_created_queue_url" {
  value = module.sqs.item_created_queue_url
}
output "match_found_queue_url" {
  value = module.sqs.match_found_queue_url
}