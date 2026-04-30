data "aws_caller_identity" "current" {}
# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  project             = var.project
  environment         = var.environment
  cidr_block          = "10.0.0.0/16"
  availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  common_tags         = local.common_tags
}

# ── IAM ───────────────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  project     = var.project
  environment = var.environment
  common_tags = local.common_tags
}

# ── ECS ───────────────────────────────────────────────────────────────────────
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

# ── RDS ───────────────────────────────────────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_sg_id          = module.ecs.ecs_node_sg_id
  db_username        = var.db_username
  db_password        = var.db_password
  common_tags        = local.common_tags
}

# ── ElastiCache ───────────────────────────────────────────────────────────────
module "elasticache" {
  source = "../../modules/elasticache"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_sg_id          = module.ecs.ecs_node_sg_id
  common_tags        = local.common_tags
}

# ── S3 ────────────────────────────────────────────────────────────────────────
module "s3" {
  source = "../../modules/s3"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
  common_tags = local.common_tags

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }
}

# ── ALB + WAF ─────────────────────────────────────────────────────────────────
module "alb" {
  source = "../../modules/alb"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  common_tags        = local.common_tags
}
# ── ECS Services ──────────────────────────────────────────────────────────────
module "ecs_services" {
  source = "../../modules/ecs-services"

  project                 = var.project
  environment             = var.environment
  aws_region              = var.aws_region
  vpc_id                  = module.vpc.vpc_id
  ecr_registry            = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  ecs_cluster_arn         = module.ecs.cluster_arn
  capacity_provider_name  = "${var.project}-cp-${var.environment}"
  task_role_arn           = module.iam.ecs_task_role_arn
  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  http_listener_arn       = module.alb.http_listener_arn
  db_host                 = module.rds.db_endpoint
  secrets_arn_prefix      = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:lostfound"
  common_tags             = local.common_tags
}