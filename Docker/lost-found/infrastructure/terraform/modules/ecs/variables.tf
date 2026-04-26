variable "project"                   { type = string }
variable "environment"                { type = string }
variable "vpc_id"                     { type = string }
variable "private_subnet_ids"         { type = list(string) }
variable "ecs_node_instance_profile"  { type = string }
variable "alb_security_group_id"      { type = string }
variable "common_tags"                { type = map(string) }
