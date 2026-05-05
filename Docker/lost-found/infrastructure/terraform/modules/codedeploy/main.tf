resource "aws_codedeploy_app" "ecs" {
  compute_platform = "ECS"
  name             = "${var.project}-ecs-${var.environment}"
  tags             = var.common_tags
}

resource "aws_codedeploy_deployment_group" "auth" {
  app_name               = aws_codedeploy_app.ecs.name
  deployment_group_name  = "${var.project}-auth-service-${var.environment}"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = var.ecs_cluster_name
    service_name = var.auth_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.http_listener_arn]
      }
      target_group { name = var.auth_tg_name }
      target_group { name = aws_lb_target_group.auth_green.name }
    }
  }

  tags = var.common_tags
}

resource "aws_lb_target_group" "auth_green" {
  name        = "${var.project}-auth-green-${var.environment}"
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

resource "aws_iam_role" "codedeploy" {
  name = "${var.project}-codedeploy-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}