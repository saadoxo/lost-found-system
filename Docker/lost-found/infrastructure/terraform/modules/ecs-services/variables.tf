variable "project"                { type = string }
variable "environment"            { type = string }
variable "aws_region"             { type = string }
variable "vpc_id"                 { type = string }
variable "ecr_registry"           { type = string }
variable "ecs_cluster_arn"        { type = string }
variable "capacity_provider_name" { type = string }
variable "task_role_arn"          { type = string }
variable "task_execution_role_arn"{ type = string }
variable "http_listener_arn"      { type = string }
variable "db_host"                { type = string }
variable "secrets_arn_prefix"     { type = string }
variable "common_tags"            { type = map(string) }
variable "images_bucket_name"     { type = string }
variable "item_created_queue_url" { type = string }
variable "match_found_queue_url"  { type = string }
variable "internal_alb_dns"       { type = string }
variable "sender_email" {
  type    = string
  default = "noreply@lostfound.internal"
}