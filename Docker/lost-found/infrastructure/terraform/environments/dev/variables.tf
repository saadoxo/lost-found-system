variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used in all resource names"
  type        = string
  default     = "lostfound"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "lostfound"
}

variable "db_password" {
  description = "RDS master password — override via TF_VAR_db_password env variable, never hardcode"
  type        = string
  sensitive   = true
}
