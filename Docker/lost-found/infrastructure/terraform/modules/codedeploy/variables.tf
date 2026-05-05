variable "project"          { type = string }
variable "environment"      { type = string }
variable "vpc_id"           { type = string }
variable "ecs_cluster_name" { type = string }
variable "auth_service_name"{ type = string }
variable "auth_tg_name"     { type = string }
variable "http_listener_arn"{ type = string }
variable "common_tags"      { type = map(string) }