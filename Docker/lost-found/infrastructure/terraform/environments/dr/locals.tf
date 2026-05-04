locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Team        = "cloud-interns"
    ManagedBy   = "terraform"
  }
}