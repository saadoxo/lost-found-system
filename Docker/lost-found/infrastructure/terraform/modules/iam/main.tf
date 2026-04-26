# IAM Role for ECS EC2 nodes
resource "aws_iam_role" "ecs_node" {
  name = "${var.project}-ecs-node-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

# Attach the AWS-managed ECS policy — lets the node register with the cluster
resource "aws_iam_role_policy_attachment" "ecs_node" {
  role       = aws_iam_role.ecs_node.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Attach SSM policy — lets you shell into nodes without SSH keys
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ecs_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile — wraps the role so EC2 can use it
resource "aws_iam_instance_profile" "ecs_node" {
  name = "${var.project}-ecs-node-profile-${var.environment}"
  role = aws_iam_role.ecs_node.name
  tags = var.common_tags
}

# IAM Role for ECS Tasks (what your containers use to call AWS services)
resource "aws_iam_role" "ecs_task" {
  name = "${var.project}-ecs-task-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

# Task execution role — lets ECS pull images from ECR and write logs
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project}-ecs-task-exec-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow tasks to read secrets from Secrets Manager
resource "aws_iam_role_policy" "task_secrets" {
  name = "${var.project}-task-secrets-${var.environment}"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:*:*:secret:${var.project}/*"
    }]
  })
}
