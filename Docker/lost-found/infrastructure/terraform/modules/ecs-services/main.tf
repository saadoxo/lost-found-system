# ── Auth Service Task Definition ──────────────────────────────────────────────
resource "aws_ecs_task_definition" "auth" {
  family                   = "${var.project}-auth-service-${var.environment}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([{
    name      = "auth-service"
    image     = "${var.ecr_registry}/lostfound/auth-service:latest"
    cpu       = 256
    memory    = 512
    essential = true

    portMappings = [{
      containerPort = 3001
      hostPort      = 0
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT",     value = "3001" },
      { name = "NODE_ENV", value = "production" },
      { name = "DB_HOST", value = replace(var.db_host, ":5432", "") },
      { name = "DB_PORT",  value = "5432" },
      { name = "DB_NAME",  value = "lostfound" },
      { name = "DB_USER",  value = "lostfound" }
    ]

secrets = [
  { name = "DB_PASSWORD",        valueFrom = "arn:aws:secretsmanager:us-east-1:395063533284:secret:lostfound/db-password-ZcjEqX" },
  { name = "JWT_ACCESS_SECRET",  valueFrom = "arn:aws:secretsmanager:us-east-1:395063533284:secret:lostfound/jwt-access-secret-hN5J7l" },
  { name = "JWT_REFRESH_SECRET", valueFrom = "arn:aws:secretsmanager:us-east-1:395063533284:secret:lostfound/jwt-refresh-secret-2va4uj" }
]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}-${var.environment}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "auth-service"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:3001/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = var.common_tags
}

# ── Item Service Task Definition ───────────────────────────────────────────────
resource "aws_ecs_task_definition" "item" {
  family                   = "${var.project}-item-service-${var.environment}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([{
    name      = "item-service"
    image     = "${var.ecr_registry}/lostfound/item-service:latest"
    cpu       = 256
    memory    = 512
    essential = true

    portMappings = [{
      containerPort = 3002
      hostPort      = 0
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT",     value = "3002" },
      { name = "NODE_ENV", value = "production" },
      { name = "DB_HOST", value = replace(var.db_host, ":5432", "") },
      { name = "DB_PORT",  value = "5432" },
      { name = "DB_NAME",  value = "lostfound" },
      { name = "DB_USER",  value = "lostfound" }
    ]

secrets = [
  { name = "DB_PASSWORD",        valueFrom = "arn:aws:secretsmanager:us-east-1:395063533284:secret:lostfound/db-password-ZcjEqX" },
  { name = "JWT_ACCESS_SECRET",  valueFrom = "arn:aws:secretsmanager:us-east-1:395063533284:secret:lostfound/jwt-access-secret-hN5J7l" },
  { name = "JWT_REFRESH_SECRET", valueFrom = "arn:aws:secretsmanager:us-east-1:395063533284:secret:lostfound/jwt-refresh-secret-2va4uj" }
]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}-${var.environment}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "item-service"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:3002/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = var.common_tags
}

# ── CloudWatch Log Group ───────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project}-${var.environment}"
  retention_in_days = 7
  tags              = var.common_tags
}

# ── ALB Target Groups ──────────────────────────────────────────────────────────
resource "aws_lb_target_group" "auth" {
  name        = "${var.project}-auth-tg-${var.environment}"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
  }

  tags = var.common_tags
}

resource "aws_lb_target_group" "item" {
  name        = "${var.project}-item-tg-${var.environment}"
  port        = 3002
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
  }

  tags = var.common_tags
}

# ── ALB Listener Rules ─────────────────────────────────────────────────────────
resource "aws_lb_listener_rule" "auth" {
  listener_arn = var.http_listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth.arn
  }

  condition {
    path_pattern { values = ["/auth", "/auth/*"] }
  }
}

resource "aws_lb_listener_rule" "item" {
  listener_arn = var.http_listener_arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.item.arn
  }

  condition {
    path_pattern { values = ["/items", "/items/*"] }
  }
}

# ── ECS Services ───────────────────────────────────────────────────────────────
resource "aws_ecs_service" "auth" {
  name            = "${var.project}-auth-service-${var.environment}"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.auth.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.auth.arn
    container_name   = "auth-service"
    container_port   = 3001
  }

  depends_on = [aws_lb_listener_rule.auth]

  tags = var.common_tags
}

resource "aws_ecs_service" "item" {
  name            = "${var.project}-item-service-${var.environment}"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.item.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.item.arn
    container_name   = "item-service"
    container_port   = 3002
  }

  depends_on = [aws_lb_listener_rule.item]

  tags = var.common_tags
}