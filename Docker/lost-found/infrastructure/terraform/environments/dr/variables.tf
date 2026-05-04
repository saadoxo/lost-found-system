variable "project"     { default = "cloudelligent-lost-found" }
variable "environment" { default = "dr" }
variable "aws_region"  { default = "us-west-2" }

variable "primary_db_identifier" {
  description = "RDS instance identifier in primary region to replicate from"
  default     = "lostfound-postgres-dev"
}