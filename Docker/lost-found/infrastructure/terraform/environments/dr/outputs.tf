output "dr_alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "dr_vpc_id" {
  value = module.vpc.vpc_id
}

output "dr_rds_replica_endpoint" {
  value     = aws_db_instance.replica.endpoint
  sensitive = true
}

output "dr_ecs_cluster_name" {
  value = module.ecs.cluster_name
}