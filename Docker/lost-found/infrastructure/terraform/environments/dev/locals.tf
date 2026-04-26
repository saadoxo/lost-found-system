locals {
  common_tags = {
    Project     = "cloudelligent-lost-found"
    Environment = var.environment
    Team        = "cloud-interns"
    ManagedBy   = "terraform"
  }
}
