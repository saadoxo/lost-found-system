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

# ── Search Service ─────────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "search" {
  family                   = "${var.project}-search-service-${var.environment}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([{
    name      = "search-service"
    image     = "${var.ecr_registry}/lostfound/search-service:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{ containerPort = 3003, hostPort = 0, protocol = "tcp" }]
    environment = [
      { name = "PORT",     value = "3003" },
      { name = "NODE_ENV", value = "production" },
      { name = "DB_HOST",  value = replace(var.db_host, ":5432", "") },
      { name = "DB_PORT",  value = "5432" },
      { name = "DB_NAME",  value = "lostfound" },
      { name = "DB_USER",  value = "lostfound" }
    ]
    secrets = [
      { name = "DB_PASSWORD", valueFrom = "arn:aws:secretsmanager:us-east-1:395063533284:secret:lostfound/db-password-ZcjEqX" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}-${var.environment}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "search-service"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:3003/health || exit 1"]
      interval    = 30, timeout = 5, retries = 3, startPeriod = 60
    }
  }])
  tags = var.common_tags
}

resource "aws_lb_target_group" "search" {
  name        = "${var.project}-search-tg-${var.environment}"
  port        = 3003
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

resource "aws_lb_listener_rule" "search" {
  listener_arn = var.http_listener_arn
  priority     = 120
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.search.arn
  }
  condition {
    path_pattern { values = ["/search", "/search/*"] }
  }
}

resource "aws_ecs_service" "search" {
  name            = "${var.project}-search-service-${var.environment}"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.search.arn
  desired_count   = 1
  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.search.arn
    container_name   = "search-service"
    container_port   = 3003
  }
  depends_on = [aws_lb_listener_rule.search]
  tags = var.common_tags
}

# ── Admin Service ──────────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "admin" {
  family                   = "${var.project}-admin-service-${var.environment}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([{
    name      = "admin-service"
    image     = "${var.ecr_registry}/lostfound/admin-service:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{ containerPort = 3007, hostPort = 0, protocol = "tcp" }]
    environment = [
      { name = "PORT",     value = "3007" },
      { name = "NODE_ENV", value = "production" },
      { name = "DB_HOST",  value = replace(var.db_host, ":5432", "") },
      { name = "DB_PORT",  value = "5432" },
      { name = "DB_NAME",  value = "lostfound" },
      { name = "DB_USER",  value = "lostfound" }
    ]
    secrets = [
      { name = "DB_PASSWORD", valueFrom = "arn:aws:secretsmanager:us-east-1:395063533284:secret:lostfound/db-password-ZcjEqX" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}-${var.environment}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "admin-service"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:3007/health || exit 1"]
      interval    = 30, timeout = 5, retries = 3, startPeriod = 60
    }
  }])
  tags = var.common_tags
}

resource "aws_lb_target_group" "admin" {
  name        = "${var.project}-admin-tg-${var.environment}"
  port        = 3007
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

resource "aws_lb_listener_rule" "admin" {
  listener_arn = var.http_listener_arn
  priority     = 130
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.admin.arn
  }
  condition {
    path_pattern { values = ["/admin", "/admin/*"] }
  }
}

resource "aws_ecs_service" "admin" {
  name            = "${var.project}-admin-service-${var.environment}"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.admin.arn
  desired_count   = 1
  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.admin.arn
    container_name   = "admin-service"
    container_port   = 3007
  }
  depends_on = [aws_lb_listener_rule.admin]
  tags = var.common_tags
}

# ── Image Service ──────────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "image" {
  family                   = "${var.project}-image-service-${var.environment}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([{
    name      = "image-service"
    image     = "${var.ecr_registry}/lostfound/image-service:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{ containerPort = 3006, hostPort = 0, protocol = "tcp" }]
    environment = [
      { name = "PORT",       value = "3006" },
      { name = "NODE_ENV",   value = "production" },
      { name = "S3_BUCKET",  value = var.images_bucket_name },
      { name = "AWS_REGION", value = var.aws_region }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}-${var.environment}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "image-service"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:3006/health || exit 1"]
      interval    = 30, timeout = 5, retries = 3, startPeriod = 60
    }
  }])
  tags = var.common_tags
}

resource "aws_lb_target_group" "image" {
  name        = "${var.project}-image-tg-${var.environment}"
  port        = 3006
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

resource "aws_lb_listener_rule" "image" {
  listener_arn = var.http_listener_arn
  priority     = 140
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.image.arn
  }
  condition {
    path_pattern { values = ["/images", "/images/*"] }
  }
}

resource "aws_ecs_service" "image" {
  name            = "${var.project}-image-service-${var.environment}"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.image.arn
  desired_count   = 1
  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.image.arn
    container_name   = "image-service"
    container_port   = 3006
  }
  depends_on = [aws_lb_listener_rule.image]
  tags = var.common_tags
}

# ── Matching Service ───────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "matching" {
  family                   = "${var.project}-matching-service-${var.environment}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([{
    name      = "matching-service"
    image     = "${var.ecr_registry}/lostfound/matching-service:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{ containerPort = 3004, hostPort = 0, protocol = "tcp" }]
    environment = [
      { name = "PORT",       value = "3004" },
      { name = "AWS_REGION", value = var.aws_region }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}-${var.environment}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "matching-service"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:3004/health || exit 1"]
      interval    = 30, timeout = 5, retries = 3, startPeriod = 60
    }
  }])
  tags = var.common_tags
}

resource "aws_ecs_service" "matching" {
  name            = "${var.project}-matching-service-${var.environment}"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.matching.arn
  desired_count   = 1
  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
  }
  tags = var.common_tags
}

# ── Notification Service ───────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "notification" {
  family                   = "${var.project}-notification-service-${var.environment}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([{
    name      = "notification-service"
    image     = "${var.ecr_registry}/lostfound/notification-service:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{ containerPort = 3005, hostPort = 0, protocol = "tcp" }]
    environment = [
      { name = "PORT",       value = "3005" },
      { name = "AWS_REGION", value = var.aws_region }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.project}-${var.environment}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "notification-service"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:3005/health || exit 1"]
      interval    = 30, timeout = 5, retries = 3, startPeriod = 60
    }
  }])
  tags = var.common_tags
}

resource "aws_ecs_service" "notification" {
  name            = "${var.project}-notification-service-${var.environment}"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.notification.arn
  desired_count   = 1
  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
  }
  tags = var.common_tags
}