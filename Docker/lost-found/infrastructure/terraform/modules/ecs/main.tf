data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-*-x86_64"]
  }
}

# Security Group for ECS EC2 nodes
resource "aws_security_group" "ecs_node" {
  name        = "${var.project}-ecs-node-sg-${var.environment}"
  description = "ECS EC2 node - accepts traffic from ALB only"
  vpc_id      = var.vpc_id

  # Accept traffic from ALB on all ports (ALB forwards to dynamic host ports)
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    description     = "From ALB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-ecs-node-sg-${var.environment}"
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.common_tags
}

# Capacity provider links the ASG to the ECS cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
    base              = 1
  }
}

resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project}-cp-${var.environment}"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 80
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 3
    }
  }
}

# Launch Template for ECS EC2 nodes
resource "aws_launch_template" "ecs_node" {
  name_prefix   = "${var.project}-ecs-node-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t3.medium"

  iam_instance_profile {
    arn = var.ecs_node_instance_profile
  }

  vpc_security_group_ids = [aws_security_group.ecs_node.id]

  # Register this instance with the ECS cluster on boot
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_TASK_IAM_ROLE=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
  EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring { enabled = true }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "${var.project}-ecs-node-${var.environment}"
    })
  }

  tags = var.common_tags
}

# Auto Scaling Group — spans all private subnets
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project}-ecs-asg-${var.environment}"
  vpc_zone_identifier = var.private_subnet_ids
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.ecs_node.id
    version = "$Latest"
  }

  # Required for ECS managed scaling
  protect_from_scale_in = true

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
