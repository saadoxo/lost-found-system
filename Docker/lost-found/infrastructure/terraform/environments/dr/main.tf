data "aws_caller_identity" "current" {}

# ── VPC (DR Region) ───────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  project              = var.project
  environment          = var.environment
  cidr_block           = "10.1.0.0/16"
  availability_zones   = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
  common_tags          = local.common_tags
}

# ── IAM ───────────────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  project     = var.project
  environment = var.environment
  common_tags = local.common_tags
}

# ── ECS Cluster (DR) ──────────────────────────────────────────────────────────
module "ecs" {
  source = "../../modules/ecs"

  project                   = var.project
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  ecs_node_instance_profile = module.iam.ecs_node_instance_profile_arn
  alb_security_group_id     = module.alb.alb_security_group_id
  common_tags               = local.common_tags
}

# ── ALB + WAF (DR) ────────────────────────────────────────────────────────────
module "alb" {
  source = "../../modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  common_tags       = local.common_tags
}

# ── KMS Key for DR RDS ────────────────────────────────────────────────────────
resource "aws_kms_key" "rds_dr" {
  description             = "KMS key for DR RDS replica"
  deletion_window_in_days = 7
  tags                    = local.common_tags
}

# ── RDS Subnet Group (DR) ─────────────────────────────────────────────────────
resource "aws_db_subnet_group" "dr" {
  name       = "lostfound-rds-subnet-group-dr"
  subnet_ids = module.vpc.private_subnet_ids
  tags       = local.common_tags
}

# ── RDS Read Replica (DR) ─────────────────────────────────────────────────────
resource "aws_db_instance" "replica" {
  identifier              = "lostfound-postgres-dr"
  replicate_source_db     = "arn:aws:rds:us-east-1:395063533284:db:lostfound-postgres-dev"
  instance_class          = "db.t3.micro"
  db_subnet_group_name    = aws_db_subnet_group.dr.name
  kms_key_id              = aws_kms_key.rds_dr.arn
  storage_encrypted       = true
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 0
  apply_immediately       = true
  tags                    = local.common_tags
}